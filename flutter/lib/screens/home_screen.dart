import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/checkout_api.dart';
import '../models/product.dart';

const _successUrl = 'payjpcheckoutexample://checkout/success';
const _cancelUrl = 'payjpcheckoutexample://checkout/cancel';

String _defaultBackendUrl() {
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _urlController =
      TextEditingController(text: _defaultBackendUrl());
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  Uri? _lastHandledLink;

  List<Product>? _products;
  Product? _selected;
  bool _loading = false;
  String? _error;
  String? _resultMessage;
  bool _awaitingRedirect = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleLink(initial);
    } catch (_) {
      // initial link 取得失敗は無視（cancel と同等）
    }
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'payjpcheckoutexample' || uri.host != 'checkout') return;
    if (_lastHandledLink == uri) return;
    _lastHandledLink = uri;
    if (!mounted) return;
    setState(() {
      _awaitingRedirect = false;
      if (uri.path == '/success') {
        _resultMessage =
            '決済受付が完了しました。Webhook での確定を確認してください。';
      } else if (uri.path == '/cancel') {
        _resultMessage = 'キャンセルされました。';
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Uri? _parseBaseUrl() {
    final text = _urlController.text.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return uri;
  }

  Future<void> _fetchProducts() async {
    final base = _parseBaseUrl();
    if (base == null) {
      setState(() => _error = 'バックエンド URL が不正です');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      final api = CheckoutApi(base);
      final list = await api.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _selected = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startCheckout() async {
    final selected = _selected;
    if (selected == null) return;
    final base = _parseBaseUrl();
    if (base == null) {
      setState(() => _error = 'バックエンド URL が不正です');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      final api = CheckoutApi(base);
      final session = await api.createSession(
        priceId: selected.id,
        quantity: 1,
        successUrl: _successUrl,
        cancelUrl: _cancelUrl,
      );
      _lastHandledLink = null;
      final ok = await launchUrl(
        session.url,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'ブラウザを起動できませんでした');
      } else {
        setState(() => _awaitingRedirect = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _products = null;
      _selected = null;
      _resultMessage = null;
      _error = null;
      _awaitingRedirect = false;
      _lastHandledLink = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PAY.JP Checkout V2 (Flutter)')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'バックエンド URL',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'http://10.0.2.2:3000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _fetchProducts,
                child: const Text('商品を取得'),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              if (_products != null) _buildProductSection(),
              if (_awaitingRedirect) ...[
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'ブラウザで Checkout を表示中です。\n'
                      '決済完了後、自動でこの画面に戻ります。',
                    ),
                  ),
                ),
              ],
              if (_resultMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_resultMessage!),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _reset,
                          child: const Text('最初からやり直す'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSection() {
    final products = _products!;
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('商品がありません'),
      );
    }
    return RadioGroup<Product>(
      groupValue: _selected,
      onChanged: (v) => setState(() => _selected = v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('商品一覧', style: Theme.of(context).textTheme.titleSmall),
          for (final p in products)
            RadioListTile<Product>(
              value: p,
              title: Text(p.name),
              subtitle: Text('¥${p.amount} / ${p.id}'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _selected == null ? null : _startCheckout,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Checkout を開く'),
          ),
        ],
      ),
    );
  }
}
