# PAY.JP Checkout V2 Flutter サンプル 設計

## 目的

Android / iOS サンプルと機能同等の Flutter 実装を提供し、同じフローで Checkout V2 を検証できるようにする。具体的には次を同じ挙動で扱う。

- バックエンド URL の設定
- 商品一覧取得（`GET /products`）
- Checkout Session 作成（`POST /create-checkout-session`）
- Checkout URL を外部ブラウザで開く
- `payjpcheckoutexample://` のディープリンクで success / cancel を受信
- 「success_url は受付シグナル。確定は Webhook」という UX ポリシーを踏襲

## 方針

- **依存を最小化**。状態管理ライブラリや永続化ライブラリは導入しない
- プラットフォーム固有コードは追加しない（`AndroidManifest.xml` と `Info.plist` でのスキーム登録のみ）
- Flutter 3.x / Dart 3.x 前提
- 画面構成は iOS サンプル（単一 `ContentView`）寄りのシンプル構成にする

## 依存パッケージ

| パッケージ | 用途 |
|------------|------|
| `http` | サーバー API 呼び出し |
| `url_launcher` | Checkout URL を外部ブラウザで起動（Android は Chrome Custom Tabs、iOS は SFSafariViewController を OS 側で選択） |
| `app_links` | `payjpcheckoutexample://checkout/success|cancel` のディープリンク購読 |

上記 3 つ以外は使わない。

## ディレクトリ構成

```
flutter/
├── pubspec.yaml
├── README.md
├── lib/
│   ├── main.dart
│   ├── api/
│   │   └── checkout_api.dart        # GET /products, POST /create-checkout-session
│   ├── models/
│   │   ├── product.dart
│   │   └── checkout_session.dart
│   └── screens/
│       └── home_screen.dart         # 単一画面（URL 入力 → 商品 → Checkout 起動 → 結果）
├── android/
│   └── app/src/
│       ├── main/AndroidManifest.xml            # intent-filter + networkSecurityConfig 参照
│       └── debug/res/xml/network_security_config.xml  # debug のみ cleartext 許可
└── ios/
    └── Runner/Info.plist            # CFBundleURLTypes を追加
```

## 画面フロー

単一画面で状態に応じて表示を切り替える。

1. **初期状態**: バックエンド URL 入力 `TextField` と「商品を取得」ボタン
2. **商品取得後**: 商品リスト → タップで選択 → 「Checkout を開く」ボタン
3. **Checkout 起動中**: ローディング表示。`app_links` のリスナでリダイレクト URI を待ち受け
4. **結果表示**:
   - `/success`: 「決済受付が完了しました。Webhook での確定を確認してください。」
   - `/cancel`: 「キャンセルされました。」
   - API / ネットワークエラー: エラーメッセージ

## データモデル

```dart
class Product {
  final String id;      // price_xxx
  final String name;
  final int amount;
}

class CheckoutSession {
  final String id;
  final Uri url;
  final String status;  // open 等
}
```

どちらも `fromJson` のみ持つ。`toJson` は不要。

## API クライアント

```dart
class CheckoutApi {
  CheckoutApi(this.baseUrl);
  final Uri baseUrl;

  Future<List<Product>> fetchProducts();

  Future<CheckoutSession> createSession({
    required String priceId,
    required int quantity,
    required String successUrl,
    required String cancelUrl,
  });
}
```

- `baseUrl` は UI 入力から生成
- HTTP エラーは例外として throw、画面側で文字列化して表示
- リクエスト / レスポンスは `server/index.js` の形状に従う

## ディープリンク処理

- `app_links` の `AppLinks` インスタンスを使い、**2 系統**を必ず併用する:
  - `getInitialLink()`（または `getInitialAppLink()`）で **コールドスタート時** に OS から渡された URI を取得
  - `uriLinkStream.listen(...)` で **アプリ生存中** に配信される URI を購読
- 既存 Android は `onCreate` で `intent?.data` を処理し、既存 iOS は `onOpenURL` で受け取っている。どちらも「起動時の初回 URI」と「実行中の追加 URI」の両方に対応しており、Flutter でも同等の二系統受信が必要
- 受信 URI が `scheme == 'payjpcheckoutexample'` かつ `host == 'checkout'`、`path` が `/success` または `/cancel` の場合のみ扱う
- 同じ URI を二重に処理しないよう、直近に処理した URI を保持して重複排除する
- iOS `Info.plist`: `CFBundleURLTypes` に `payjpcheckoutexample` を追加
- Android `AndroidManifest.xml`: `MainActivity` に `<intent-filter>` を追加（scheme=`payjpcheckoutexample`, host=`checkout`, pathPrefix=`/success` と `/cancel`）

## success_url の扱い

- クライアントは「決済完了」判定をしない
- 画面文言で「受付完了 / 確定は Webhook」と明示する
- 確定処理（発送など）はサーバーの `checkout.session.completed` Webhook 側に任せる

## バックエンド URL の既定値

| 環境 | 既定値 |
|------|--------|
| Android エミュレータ | `http://10.0.2.2:3000` |
| iOS シミュレータ | `http://localhost:3000` |
| 実機 | 空欄（ユーザーが LAN IP を入力） |

`Platform.isAndroid` / `Platform.isIOS` で判定。永続化はしない（起動ごとに入力／既定値からやり直し）。

## Android のローカル HTTP 接続要件

既存 Android サンプルと同様、Android 9 (API 28) 以降は既定で cleartext HTTP が禁止されるため、ローカル開発サーバー（`http://10.0.2.2:3000` / `http://192.168.x.x:3000`）に接続するには `networkSecurityConfig` の設定が必要。

- `android/app/src/main/AndroidManifest.xml` の `<application>` に `android:networkSecurityConfig="@xml/network_security_config"` を指定
- `android/app/src/debug/res/xml/network_security_config.xml` に **debug ビルドのみ** cleartext を許可する設定を置く

```xml
<!-- debug/res/xml/network_security_config.xml -->
<network-security-config>
  <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

release ビルド用のファイルは用意しない（Android 既定の `cleartextTrafficPermitted="false"` が有効）。本番接続は HTTPS を前提とする。

## エラーハンドリング

- HTTP エラー: ステータスコードとレスポンスボディを画面に表示
- ネットワークエラー: 例外メッセージを表示
- ディープリンクが来ないケース: タイムアウトは設けず、「戻る」ボタンで初期状態に戻せるようにする

## 既存 Android / iOS サンプルとの差分

- 永続化 UI なし（Android の `SharedPreferences` 相当は省略）
- 単一画面構成（Android の 2 Activity 構成より iOS 実装に近い）
- 機能的差分なし。URL スキーム、API 形状、success_url の扱いは完全に同一

## 本サンプルでは扱わない範囲

- URL の永続化（必要になれば `shared_preferences` を追加）
- 状態管理ライブラリ（`provider` / `riverpod`）
- 複数商品カート / 数量変更 UI
- テストコード
