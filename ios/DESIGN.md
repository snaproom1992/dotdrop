# DOT DROP — iOS ネイティブ移植 設計書

ブラウザ版（`index.html`）を、Swift で iOS アプリとして作り直す。  
**見た目・手触り・バランスの正解は今の Web 版**。物理は今の ENGINE をベースに突き合わせる。

## ゴール

- App Store で配布できる iOS アプリ（縦固定・iPhone 優先）
- フリープレイ＋あそびかた（チュートリアル）を最初の範囲にする
- 1 ゲーム 25〜35 打・ステージ別の玉増減など、今のバランスを維持する
- ブラウザ版（GitHub Pages）は残す。並行して育てる

## やらないこと（最初の版）

- ミッション／タイムアタック／最少球数（構想のみ。データ形は `STEPS` 流用予定）
- Android
- SpriteKit / GameplayKit の物理エンジン差し替え（独自物理を移植する）

## 全体構成

```
ios/
  DESIGN.md                 … この設計
  README.md                 … Mac での開き方
  DotDrop/                  … Xcode アプリ（UI・音・保存）
  DotDropEngine/            … 画面なしの物理・ルール（テスト可能）
  tools/dump-fixtures.js    … JS ENGINE から正解データを出す
```

責務の分け方は Web 版と同じ発想にする。

| 層 | 担当 | Web 版の対応 |
|----|------|----------------|
| **DotDropEngine** | 物理・台・受け皿・フィーバー・PERFECT・フック | `/*ENGINE*/` 〜 `/*END*/` |
| **Game** | 持ち玉・ステージ進行・モード（フリー／あそびかた） | `applyConf` 以降のルール接続 |
| **Render** | 釘・玉・受け皿・帯・HUD | canvas 描画 |
| **Input** | 引っ張り発射・シート | pointer 操作 |
| **Audio / Haptics** | 効果音・節目・振動 | Web Audio / vibrate |
| **Store** | ランキング・記録・チュートリアル進捗 | `localStorage` |

Engine は UIKit / SwiftUI に依存しない。  
`balance.js` と同様、画面なしで `stepPhysics` を回せる形を保つ。

## 技術選定

| 項目 | 採用 | 理由 |
|------|------|------|
| UI 枠 | SwiftUI | タイトル・結果・あそびかた一覧に合う |
| 盤面描画 | SwiftUI `Canvas` または `UIView` 直描き | Web と同じ「毎フレーム全部描く」に近い。SpriteKit 物理は使わない |
| 物理 | 自前（JS ENGINE の移植） | バランスと手触りの再現が最優先 |
| 音 | AVAudioEngine で合成 | Web と同じくファイルなし方針を維持できる |
| 振動 | `UIImpactFeedbackGenerator` など | iOS 標準。checkbox switch ハックは不要 |
| 保存 | `UserDefaults`（必要なら後で File） | `dotdrop-ranking` 等と同趣旨のキー |
| テスト | XCTest ＋ JS フィクスチャ | 下記「物理の突き合わせ」 |

最低サポート：iOS 17 想定（SwiftUI Canvas・セーフエリアが楽）。必要なら後で下げる。

## 座標とタイミング

Web と同じ論理座標を Engine の中だけで使う。

- 論理幅 `LW = 360`
- 論理高さ `E.LH`（Web は `fit()` で決まる。初期 700）
- 発射位置 `LAUNCH = (180, 140)`
- 物理刻み `dt = 1/360`（1 フレームを 6 分割している今と同じ）

画面への写し方だけ Swift 側でスケールする（`scale = min(viewW/LW, usableH/LH)`）。  
セーフエリア（ノッチ・ホームバー）の扱いは Web の `fit()` と同じ考え方にする。

## 物理の突き合わせ（今の balance.js ベース）

### 方針

1. **正解は JS の ENGINE**（`index.html` の `/*ENGINE*/`）
2. Swift の `DotDropEngine` を、同じ入力で同じ出力になるまで近づける
3. バランス数字を変えたら、今まで通り `node balance.js` も回す（Web／共通の真実）

### 乱数

ENGINE 内の乱数は役割が分かれている。

- **台の種**（`boardSeed` + `seeded`）→ 同じ種なら同じ台・同じ ▲
- **はなす瞬間のブレ** → いつも毎回ちがう（テストでは `exact` 相当でオフ）
- **分裂・青の放出・跳ねの微小ブレ** → `Math.random`

Swift 側では最初から **RNG を差し替え可能** にする。  
フィクスチャ生成時は JS 側も同じ列の乱数を使えるよう、必要なら ENGINE に「テスト用 RNG」を足す（画面挙動は変えない）。

### テストの段階

1. **決定的ユニット**（種つきレイアウト、`slotInfo`、フィーバー変換、受け皿 index）
2. **1 打の軌道フィクスチャ**（`dump-fixtures.js` → JSON → XCTest）
3. **統計的バランス**（Swift でも `balance.js` 相当を後から。当面は JS の `balance.js` を正とする）

### フィクスチャの中身（例）

- `boardSeed`, layout, stage, fever
- 発射 `vx, vy`（ブレなし）
- 乱数シードまたは消費列
- 結果: `hitCount`, `shotPay`, `shotScore`, ヒット種別カウント, 着地スロット列

## 画面フロー

Web と同じ。

1. タイトル（DOT の O が玉）→ はじめる / あそびかた
2. プレイ（HUD・リセットシート・帯）
3. 結果（スコア・ランキング・もう一度・タイトルへ）
4. あそびかた一覧 → 各 STEP

文言ルールも踏襲する（画面の英語／説明の日本語、■●▲ など見えている名前だけ）。

## 実装フェーズ

| 順 | 内容 | 完了の目安 |
|----|------|------------|
| 0 | 本設計・空プロジェクト・フィクスチャ骨組み | この PR |
| 1 | Engine 移植＋フィクスチャ一致 | `exact` 発射の数ケースが JS と一致 |
| 2 | 盤面描画＋引っ張り発射 | iPhone で打って落ちる |
| 3 | スコア・持ち玉・ステージ・フィーバー | フリープレイが最後まで遊べる |
| 4 | 音・振動・演出（帯・数字ドン） | 手触りが Web に近づく |
| 5 | タイトル・結果・保存・あそびかた | ストア提出候補 |
| 6 | TestFlight → 審査 | 実機で作者確認 |

## Mac 側（あなた）の作業

このクラウドでは Xcode ビルドはできない。あなたの Mac で:

1. このリポジトリを pull
2. `ios/README.md` の手順で Xcode プロジェクトを生成／開く
3. シミュレータまたは実機で確認
4. 触感のフィードバックを返す（今まで通り）

Apple Developer アカウントはすでにある前提で、署名・Bundle ID は Xcode 上で設定する。

## リスクと避け方

| リスク | 避け方 |
|--------|--------|
| 物理が微妙にずれてバランス崩壊 | フィクスチャ＋ `balance.js` を正とする。描画より先に Engine |
| 乱数差でテストが不安定 | RNG 注入・`exact` 発射 |
| 大きな一発移植で手触り確認が遅れる | フェーズを小さく。まず「打って落ちる」 |
| Web と iOS で数字が分岐 | 定数は Engine にだけ置く。変えたら両方のテスト |

## 参考（Web の定数・入口）

- `applyConf` / `DEFAULTS` … モード差し替え
- `setLayout` / `pickGold` / `launch` / `launchVelocity` / `stepPhysics`
- `SLOT_M` / `STAGE_B` / `FEVER_AT` / `FEVER_SHOTS` / `PERFECT`
- `balance.js` … バランス確認の正解手順
