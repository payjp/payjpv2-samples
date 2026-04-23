# PAY.JP Checkout V2 Expo サンプル

Expo (React Native) から PAY.JP Checkout V2 を試すサンプルアプリです。`server/` のサンプル API と連携し、`expo-web-browser` の認証セッションで Checkout を開き、カスタムスキームのリダイレクトで結果を受け取ります。

PAY.JP Checkout V2 の新 SDK はネイティブモジュールを追加する必要がなく、Web ビュー + URL スキームだけで動くため、Expo の managed workflow（ネイティブビルド不要）で実装できます。

## 前提条件

- Node.js 18 以上
- Expo Go（動作確認に便利）または EAS Build
- `server/` が `http://localhost:3000` で起動していること

## 起動手順

```bash
cd react-native-expo
npm install
npm start           # Metro + Expo DevTools
# 別ターミナルやホットキーから
npm run ios         # iOS シミュレータ
npm run android     # Android エミュレータ / 実機
```

`npx expo run:ios` / `npx expo run:android` でもそれぞれ起動可。CLI から直接 `pod install` を呼ぶ必要はありません（Expo が内部で解決）。

## 画面フロー

1. バックエンド URL 入力（既定: Android=`http://10.0.2.2:3000` / iOS=`http://localhost:3000`）
2. 「商品を取得」で `/products` を呼ぶ
3. 商品を選択 →「Checkout を開く」で `/create-checkout-session` → `expo-web-browser` が認証セッションで Checkout を表示
4. 決済完了 / キャンセルで `payjpcheckoutexample://checkout/success|cancel` にリダイレクトされると、`openAuthSessionAsync` が自動で閉じて結果 URL を返す
5. 結果メッセージを表示。「最初からやり直す」で初期状態へ

## success_url は「受付シグナル」

Android / iOS / Flutter / bare RN サンプルと同じ方針で、`success_url` にリダイレクトされた時点では **決済完了ではなく受付済み** として扱います。確定判定はサーバーの `checkout.session.completed` Webhook 側で行ってください。

## ディープリンク設定

`app.json` の `"scheme": "payjpcheckoutexample"` 1 行だけ。

- `AndroidManifest.xml` の `<intent-filter>` 編集不要
- `Info.plist` の `CFBundleURLTypes` 編集不要
- `AppDelegate` の `application:openURL:` 実装不要

Expo のプリビルドがネイティブ側を生成してくれます。

## expo-web-browser.openAuthSessionAsync

bare RN サンプル（`react-native/`）では、外部ブラウザで Checkout を開いて `Linking.addEventListener('url', ...)` + `Linking.getInitialURL()` でリダイレクトを拾い、コールドスタート対策で直近 URI の重複処理もしていました。

Expo では `openAuthSessionAsync(url, redirectUrl)` がこれを内包します。

- iOS: `ASWebAuthenticationSession`
- Android: Chrome Custom Tabs

ブラウザセッション内でリダイレクトが発生した時点で自動的に閉じ、戻り値として `{type: 'success', url}` を返すため、URL リスナの登録やコールドスタート復帰の設計が不要です。

## Android のローカル HTTP 接続

ローカル開発の `http://10.0.2.2:3000` に接続する場合、Android のクリアテキスト HTTP 制限に注意してください。Expo では `app.json` で

```json
"android": {
  "usesCleartextTraffic": true
}
```

を使うか、release ビルドでは HTTPS を用意してください。このサンプルは既定で debug 接続のみを想定しています。

## テスト

```bash
npm test
```

`parseRedirect` の単体テストを `jest-expo` プリセットで実行します。
