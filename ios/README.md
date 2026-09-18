# DOT DROP iOS

**完全再現**：アプリは `index.html` をそのまま WKWebView で動かします。  
見た目・配置・物理・音・あそびかたは、リポジトリ直下の Web 版と同一コードです。

## 開き方

```bash
cd ~/dotdrop
git pull
open ios/DotDrop/DotDrop.xcodeproj
```

Xcode で Team を選んで ▶ Run。

## Web 版を直したあと

`index.html` などを変えたら、アプリ同梱分を同期してからビルド：

```bash
bash ios/tools/sync-www.sh
```

## 構成

| パス | 内容 |
|------|------|
| `DotDrop/Resources/www/` | 同梱された `index.html` 一式（本番プレイ） |
| `DotDrop/App/WebGameView.swift` | WKWebView の箱だけ |
| `DotDropEngine/` | JS ENGINE との突き合わせ用（テスト）。アプリ本体の描画には使わない |

## 方針

- ゲームの中身は `index.html` が正本
- iOS 側は App Store 用の箱（アイコン・向き・フルスクリーン）に徹する
- 「Swift で別実装して近づける」はやめ、渡されたコードをそのまま載せる
