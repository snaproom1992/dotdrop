# DOT DROP iOS

ネイティブ（Swift）移植用のフォルダです。設計は [DESIGN.md](./DESIGN.md) を見てください。

## 必要なもの（あなたの Mac）

- Xcode 15 以降（おすすめ）
- Apple Developer アカウント（実機・提出用。すでに所持）

XcodeGen は不要です。`.xcodeproj` をリポジトリに入れています。

## 開き方（これだけ）

```bash
cd ~/dotdrop   # clone した場所
git pull
open ios/DotDrop/DotDrop.xcodeproj
```

Xcode で Team を選んで ▶ Run。  
タイトルの ▶ から、**引っ張ってはなす**簡易プレイに入れます。

## テスト（Mac）

Xcode で `DotDropEngine` パッケージのテストを実行するか:

```bash
cd ios/DotDropEngine
swift test
```

`shots.json`（JS ENGINE の正解）と hitCount / shotPay / shotScore、および釘配置が一致することを見ます。

フィクスチャの再生成（数字や ENGINE を変えたら）:

```bash
node ios/tools/dump-fixtures.js
```

## 構成

| パス | 内容 |
|------|------|
| `DotDrop/DotDrop.xcodeproj` | Xcode で開くプロジェクト |
| `DotDrop/App` | アプリ画面（SwiftUI） |
| `DotDropEngine/` | 物理・ルールの Swift Package |
| `tools/dump-fixtures.js` | Web の ENGINE から正解 JSON を出す |

## 物理フィクスチャの出し方

リポジトリルートで:

```bash
node ios/tools/dump-fixtures.js
```

## バランス確認

玉の増減に関わる数字を変えたら、今まで通り:

```bash
node balance.js
```
