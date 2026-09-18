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

## レイアウト注意

- `RootView` は全画面 `fit()` のため `.ignoresSafeArea()` する。そのままだと
  `GeometryReader.safeAreaInsets` が 0 になり、HUD が Dynamic Island にめり込む。
  → `ScreenSafeArea`（UIWindow の insets）を使い、CSS の `env(safe-area-inset-*)` と同じ値を渡す
- タイトルの O は固定サイズの Canvas アニメ。`alignmentGuide` は使わない（AttributeGraph cycle）
- `GameSession` は `@Observable`。`pullX/Y` と `engine` は `@ObservationIgnored`
  （ドラッグや物理のたびに RootView 全体が再構築されないようにする）
- `BoardCanvas` の `TimelineView` は **`timeline.date` を Canvas 内で読む**こと。
  読まないと Canvas が再描画されず、受け皿も脈打ちも止まる
- 発射 Y は帯と同じくノッチ分だけ下げる（上限 26）。STAGE と玉の重なり防止

## フィーバー（Web と同じ）

- 釘ヒットのポイントを `gauge` に加算（受け皿倍率は含めない）
- `FEVER_AT = 120` で、打ち終わり（`shotEnd`）に突入、`FEVER_SHOTS = 3`
- ▲ 連鎖で1回の放出でも 120 を超えやすい（仕様どおり。早すぎる感じが出やすい）

## 署名（初回だけ）

実機／シミュレータで走らせるには Development Team が必要です。どちらか一方でOK。

1. **かんたん**: Xcode → ターゲット DotDrop → Signing & Capabilities → Team を選ぶ  
2. **ファイルで固定**（推奨・Team ID を git に載せない）:
   ```bash
   cp ios/DotDrop/Config/Signing.xcconfig.example ios/DotDrop/Config/Signing.xcconfig
   # Signing.xcconfig の YOUR_TEAM_ID を自分の Team ID に書き換え
   ```
   Team ID は [developer.apple.com/account](https://developer.apple.com/account) の Membership にあります。

## 未接続（次）

- あそびかた（STEPS 全接続）
- ランキング／記録の完全移植

## 演出ギャップ（index.html と照合・2026-09）

### いまある（簡易含む）
- 受け皿の流れ／発射前の脈打ち・点線弧・狙い／釘の pulse・lit・boardHit
- 青●つかみ中の縮小／▲の点滅・半透明／台切り替えの移動（m）
- 帯の表示（スライド・文字サイズ自動縮小なし）／タイトル O の dropIn
- 音・振動の基本
- **玉の軌跡**（trail + 外周グロー）
- **吹き出し** floaters（`12×3` / `+pts` / `+玉` / `×0`）
- **吸い込み** flyers（スコア粒・戻る玉・減る玉の点線）※届いてから持ち玉／スコア加算
- **光の柱** catches（単色の簡易版）

### まだない（アニメ・演出）
- 外れ玉 fallen／slotFlash
- **命中波** waves（周囲の釘が膨らむ）
- **数字ドン** milestoneFx（背景フラッシュ・巨大数字・ふち edge）
- **今回ポイント** 背景の大きな pot 数字（potShow / potAlpha）
- **画面揺れ** shake／**ヒットストップ** hitStop／スロー slowPulse
- **PERFECT** 赤い波＋脈打ち＋歓声まわりの描画
- **帯** の横スライド・区切り線・自動縮尺
- **HUD** リール回転（Roller）と bump 拡大
- 青●の「つかんでいるとき大きく」／waves 分の grow
- フィーバー背景の滑らかな色補間
- 光の柱のグラデーション（いまは単色）