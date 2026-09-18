# DOT DROP — iOS ネイティブ移植

## 方針

- **App Store 審査を通すため、ネイティブ（SwiftUI + 自前 Engine）で実装する**
- WKWebView で HTML を包む方式は使わない（申請で弾かれやすい）
- **見た目・配置・物理の正本は `index.html`**
  - 色・余白・HUD は CSS の数値を写す（`Theme` / `GameHUD` / `TitleView`）
  - 物理は `/*ENGINE*/` を `DotDropEngine` に移植（数値の独自調整はしない）
  - 盤面は `draw()` の順と色に合わせる（`BoardCanvas`）

## 構成

```
ios/DotDrop/App/
  Theme.swift        … :root / fit()
  GameSession.swift  … フリープレイ進行
  TitleView.swift    … #start
  GameHUD.swift      … <header>
  BoardCanvas.swift  … canvas draw
  ResultOverlay.swift… #over / #sheet
  RootView.swift     … overlay 切り替え
DotDropEngine/       … ENGINE + フィクスチャテスト
```

## 未接続（次）

- あそびかた（STEPS 全接続）
- 音・振動
- ランキング／記録の完全移植
- 帯・数字ドン・PERFECT 演出の細部
