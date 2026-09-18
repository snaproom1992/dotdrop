# DOT DROP — iOS 移植 設計書

## 方針（確定）

**完全再現。** ゲーム本体はリポジトリ直下の `index.html`（および付随アセット）が正本。  
iOS アプリはそれを WKWebView でフルスクリーン表示する箱である。

- 見た目・配置・HUD・受け皿・物理・音・あそびかた・結果画面は、Web と同じコードパスを通る
- Swift で簡略 UI を書き直して「近づける」ことはしない
- `index.html` を直したら `bash ios/tools/sync-www.sh` で `ios/DotDrop/Resources/www/` に同期してからビルドする

以前試した Swift 独自描画（PlayView）は、配置も手触りも別物になったため撤去した。

## 構成

```
ios/
  DESIGN.md
  README.md
  tools/sync-www.sh          … 正本 → www へコピー
  DotDrop/
    App/WebGameView.swift    … WKWebView
    App/DotDropApp.swift
    Resources/www/           … 同梱された index.html 一式
  DotDropEngine/             … ENGINE 突き合わせ用（任意・テスト）
```

## App Store 向けに箱側で持つもの

- Bundle ID / 署名 / アイコン
- 縦固定・ステータスバー非表示
- セーフエリアは HTML 側の `env(safe-area-inset-*)` と `fit()` に任せる

## DotDropEngine について

JS の `/*ENGINE*/` を Swift に移植したパッケージは残す（フィクスチャ突き合わせ用）。  
**アプリのプレイ画面には使わない。** 正本は常に `index.html`。
