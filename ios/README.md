# DOT DROP iOS

ネイティブ（Swift）移植用のフォルダです。設計は [DESIGN.md](./DESIGN.md) を見てください。

## 必要なもの（あなたの Mac）

- Xcode 15 以降（おすすめ）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（アプリの `.xcodeproj` を生成する）
  ```bash
  brew install xcodegen
  ```
- Apple Developer アカウント（実機・提出用。すでに所持）

## 初回セットアップ

```bash
cd ios/DotDrop
xcodegen generate
open DotDrop.xcodeproj
```

Xcode で:

1. Signing & Capabilities で Team を選ぶ
2. Bundle Identifier を自分用に変える（例: `com.yourname.dotdrop`）
3. シミュレータまたは実機で Run

## 構成

| パス | 内容 |
|------|------|
| `DotDrop/` | アプリ本体（SwiftUI）。今はプレースホルダ画面 |
| `DotDropEngine/` | 物理・ルールの Swift Package（画面なし） |
| `tools/dump-fixtures.js` | Web の ENGINE から正解 JSON を出す |

## 物理フィクスチャの出し方

リポジトリルートで:

```bash
node ios/tools/dump-fixtures.js
```

`ios/DotDropEngine/Tests/Fixtures/shots.json` が更新されます。  
Swift のテストは、この JSON と Engine の結果を比べます（Engine 実装が進んだら意味を持ちます）。

## バランス確認

玉の増減に関わる数字を変えたら、今まで通り:

```bash
node balance.js
```

iOS 専用の数字分岐は作らない方針です（設計書参照）。
