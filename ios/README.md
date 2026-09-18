# DOT DROP iOS

ネイティブ（Swift）移植。正本はリポジトリ直下の `index.html`。

## 開き方

```bash
cd ~/dotdrop
git pull
open ios/DotDrop/DotDrop.xcodeproj
```

Signing で Team を選び、Clean Build Folder → Run。

## 確認ポイント

- タイトル：DOT の O が落ちる／■●▲／はじめる／あそびかた
- プレイ：リセットが中央上、持ち玉左・STAGE中央・スコア右+FEVER
- 受け皿が下を流れ、×・●・点線が見える
- 物理は Web と同じ ENGINE 数値
