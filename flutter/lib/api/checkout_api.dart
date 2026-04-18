import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/checkout_session.dart';
import '../models/product.dart';

class CheckoutApiException implements Exception {
  CheckoutApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CheckoutApi {
  CheckoutApi(this.baseUrl);

  final Uri baseUrl;

  Future<List<Product>> fetchProducts() async {
    final res = await http.get(baseUrl.resolve('/products'));
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['products'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return list.map(Product.fromJson).toList(growable: false);
  }

  Future<CheckoutSession> createSession({
    required String priceId,
    required int quantity,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final res = await http.post(
      baseUrl.resolve('/create-checkout-session'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'price_id': priceId,
        'quantity': quantity,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      }),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return CheckoutSession.fromJson(body);
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw CheckoutApiException(
      'HTTP ${res.statusCode}: ${res.body}',
    );
  }
}
