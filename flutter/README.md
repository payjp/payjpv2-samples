# PAY.JP Checkout V2 Flutter サンプル

Flutter から PAY.JP Checkout V2 を試すためのサンプルアプリです。`server/` のサンプル API と連携し、外部ブラウザで Checkout を開いてカスタムスキームのディープリンクで結果を受け取ります。

## 前提条件

- Flutter 3.41 以上（Dart 3.11 以上）
- Android Studio / Xcode がセットアップ済み
- `server/` が `http://localhost:3000` で起動している
- iOS ビルドには CocoaPods が必要（`sudo gem install cocoapods` など）

## 依存パッケージ

| パッケージ | 用途 |
|------------|------|
| `http` | サンプル API 呼び出し |
| `url_launcher` | Checkout URL を外部ブラウザで起動（Android は Custom Tabs、iOS は SFSafariViewController を OS が選択） |
| `app_links` | `payjpcheckoutexample://checkout/success|cancel` のディープリンク受信 |

状態管理ライブラリや永続化ライブラリは導入していません（素の `StatefulWidget` / `setState`）。

## 起動手順

### 1. 依存関係を取得

```bash
cd flutter
flutter pub get
```

iOS 向けに追加で:

```bash
cd ios
pod install
cd ..
```

### 2. アプリを実行

```bash
# Android エミュレータ
flutter run -d emulator-5554

# iOS シミュレータ
flutter run -d "iPhone 15"
```

### 3. バックエンド URL

起動時に既定値が入ります。

| 環境 | 既定値 |
|------|--------|
| Android エミュレータ | `http://10.0.2.2:3000` |
| iOS シミュレータ | `http://localhost:3000` |
| 実機 | 開発マシンの LAN IP（例: `http://192.168.1.10:3000`）に手動変更 |

永続化はしません。起動ごとに入力してください。

## 画面フロー

単一画面で状態に応じて UI を切り替えます。

1. バックエンド URL を入力 → 「商品を取得」
2. 商品リストから 1 件選択 → 「Checkout を開く」
3. 外部ブラウザで Checkout 画面が開く
4. 決済完了 / キャンセル後に `payjpcheckoutexample://checkout/success|cancel` でアプリに戻る
5. 結果メッセージを表示。「最初からやり直す」で初期状態へ

## success_url は「受付シグナル」

Android / iOS サンプルと同じ方針で、`success_url` にリダイレクトされた時点では **決済完了ではなく受付済み** として扱います。確定判定はサーバーの `checkout.session.completed` Webhook 側で行ってください。

## ディープリンク設定

### Android

`android/app/src/main/AndroidManifest.xml` の `MainActivity` に `<intent-filter>` を登録しています（scheme=`payjpcheckoutexample`, host=`checkout`, pathPrefix=`/success` / `/cancel`）。

コールドスタート時の URI は `AppLinks.getInitialLink()` で、実行中に受ける URI は `uriLinkStream` で取得し、両方を同じハンドラで処理しています（`lib/screens/home_screen.dart`）。

### iOS

`ios/Runner/Info.plist` の `CFBundleURLTypes` に `payjpcheckoutexample` スキームを登録しています。ハンドリングは Android と同じ経路で行います。

## Android のローカル HTTP 接続

Android 9 (API 28) 以降は既定で cleartext HTTP が禁止されるため、`networkSecurityConfig` を次のように用意しています。

- `android/app/src/main/res/xml/network_security_config.xml`: release では cleartext を拒否
- `android/app/src/debug/res/xml/network_security_config.xml`: debug のみ cleartext を許可（ローカル開発用）

release ビルドから本番サーバーに接続する際は HTTPS を使ってください。

## ディレクトリ構成

```
flutter/
├── DESIGN.md
├── lib/
│   ├── main.dart
│   ├── api/checkout_api.dart
│   ├── models/{product,checkout_session}.dart
│   └── screens/home_screen.dart
├── android/app/src/main/AndroidManifest.xml
├── android/app/src/main/res/xml/network_security_config.xml
├── android/app/src/debug/res/xml/network_security_config.xml
└── ios/Runner/Info.plist
```

## 設計メモ

設計の背景や方針については [`DESIGN.md`](DESIGN.md) を参照してください。
