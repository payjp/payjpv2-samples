# PAY.JP Checkout V2 React Native サンプル

React Native から PAY.JP Checkout V2 を試すためのサンプルアプリです。`server/` のサンプル API と連携し、OS 標準のブラウザで Checkout を開いてカスタムスキームのディープリンクで結果を受け取ります。

## 前提条件

- Node.js 18 以上
- React Native 環境（Android Studio / Xcode セットアップ済み）
- `server/` が `http://localhost:3000` で起動している
- iOS ビルドには CocoaPods が必要（`brew install cocoapods` など）

## 依存関係

追加の React Native パッケージは使っていません。

- HTTP: `fetch`（組み込み）
- 外部ブラウザ起動 & ディープリンク: `Linking`（組み込み）
- 状態管理: `useState` / `useEffect`（組み込み）

状態管理ライブラリや永続化ライブラリは導入していません。

## 起動手順

### 1. 依存関係を取得

```bash
cd react-native
npm install
```

iOS 向けに追加で:

```bash
cd ios
bundle install   # 初回のみ
bundle exec pod install
cd ..
```

### 2. Metro を起動（別シェル）

```bash
npm start
```

### 3. アプリを実行

```bash
# Android エミュレータ / 実機
npm run android

# iOS シミュレータ
npm run ios
```

## 画面フロー

1. バックエンド URL 入力（既定: Android=`http://10.0.2.2:3000` / iOS=`http://localhost:3000`）
2. 「商品を取得」で `/products` を呼ぶ
3. 商品を選択 →「Checkout を開く」で `/create-checkout-session` → `Linking.openURL()` で外部ブラウザに遷移
4. 決済完了 / キャンセル後に `payjpcheckoutexample://checkout/success|cancel` でアプリに戻る
5. 結果メッセージを表示。「最初からやり直す」で初期状態へ

## success_url は「受付シグナル」

Android / iOS / Flutter サンプルと同じ方針で、`success_url` にリダイレクトされた時点では **決済完了ではなく受付済み** として扱います。確定判定はサーバーの `checkout.session.completed` Webhook 側で行ってください。

## ディープリンク設定

### Android

- `android/app/src/main/AndroidManifest.xml` の `MainActivity` に `<intent-filter>` を追加（scheme=`payjpcheckoutexample`, host=`checkout`, pathPrefix=`/success` / `/cancel`）。
- `launchMode="singleTask"` のまま利用。URL が戻ってきたときの intent を `Linking.getInitialURL()` が拾えるよう、`MainActivity.onNewIntent(intent)` 内で `setIntent(intent)` を呼び直しています。

### iOS

- `ios/PayJPCheckoutExample/Info.plist` の `CFBundleURLTypes` に `payjpcheckoutexample` を登録。
- `AppDelegate.swift` で `application:openURL:options:` を実装し、`RCTLinkingManager` に転送。

## Android のローカル HTTP 接続

Android 9 (API 28) 以降は既定で cleartext HTTP が禁止されるため、`networkSecurityConfig` を次のように用意しています。

- `android/app/src/main/res/xml/network_security_config.xml`: release では cleartext を拒否
- `android/app/src/debug/res/xml/network_security_config.xml`: debug のみ cleartext を許可（ローカル開発用）

release ビルドから本番サーバーに接続する際は HTTPS を使ってください。

## ディープリンク受信の 2 系統

React Native の `Linking` で 2 つの経路を併用して、コールドスタートと実行中の両方に対応します。

- `Linking.getInitialURL()`: アプリが URL で起動された場合の初回 URI
- `Linking.addEventListener('url', ...)`: 実行中のアプリに配信される URI

同一 URI を二重処理しないよう、直近に処理した URI を保持しています（`App.tsx`）。
