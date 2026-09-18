# DOT DROP iOS

ネイティブ（Swift）移植用のフォルダです。設計は [DESIGN.md](./DESIGN.md) を見てください。

## 必要なもの（あなたの Mac）

- Xcode 15 以降（おすすめ）
- Apple Developer アカウント（実機・提出用。すでに所持）

XcodeGen は不要です。`.xcodeproj` をリポジトリに入れています。

## 開き方（これだけ）

1. このリポジトリを Mac に取る（まだなら clone／あれば pull）

```bash
git fetch origin
git checkout cursor/ios-native-design-9ade
```

2. Finder で次のファイルをダブルクリックする（またはターミナル）

```bash
open ios/DotDrop/DotDrop.xcodeproj
```

3. Xcode で
   - 左の **DotDrop** プロジェクト → **Signing & Capabilities**
   - **Team** に自分の Apple ID / Developer を選ぶ
   - 必要なら Bundle Identifier を変える（例: `com.yourname.dotdrop`）
   - 上で iPhone シミュレータを選んで ▶ Run

いまは「準備中」のプレースホルダ画面が出れば成功です。

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
