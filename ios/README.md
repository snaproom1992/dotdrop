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

## UIブラッシュアップ

- タイトル：Helvetica Neue Bold 76pt、行高0.9、Oを玉として描画。落下・つぶれ・跳ね返り・軌跡を補間。
- HUD：0.57em幅の数字リール、数字の実際の位置に向かう得点・持ち玉の回収演出。
- 結果：スコアのカウントアップ、順位表示、余白・数字の字間を調整。
- あそびかた：8レッスン、クリア状況の保存、次のレッスンへの導線。
- 中断：アプリ切替・着信で停止し、「つづける」で再開。アプリ終了後の途中再開は未対応。
- リセット画面：「音・振動・演出」からサウンド、触覚、点滅・揺れを切替可能。
- PERFECT：演出だけでなく総合スコアにもボーナスを反映。

### 検証コマンド（Mac）

```bash
swift test --package-path ios/DotDropEngine
xcodebuild -project ios/DotDrop/DotDrop.xcodeproj -scheme DotDrop \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

物理比較にはHTML版の既存ショットを使用。盤面配置はネイティブ版で以前から使っている
336ptの高さ制限を維持し、同じ境界条件を与えたJavaScriptの配置と16ケースを照合する。
配置参照の再生成は `node ios/tools/dump-native-layouts.js`。

### 実機での確認

1. 小型・大型iPhoneでタイトルの行間、Oの着地、左右の中心を確認。
2. 持ち玉とスコアが1桁から複数桁になっても欠けず、回収演出の着地点が数字に合うこと。
3. 8レッスンの成功・失敗・再挑戦・一覧復帰と、再起動後のクリア印を確認。
4. 最後の玉で得点・持ち玉・PERFECTを獲得しても、回収前に結果へ進まないこと。
5. プレイ中のアプリ切替・着信・復帰で停止位置を維持し、音が残らないこと。
6. 効果音と振動を実機で確認。サウンドOFF・振動OFF・視差効果を減らす設定も確認。
7. 結果のカウントアップとランキング、リセットのキャンセル・外側タップ・下スワイプを確認。

SwiftUIの画面、Core Haptics、オーディオの実機品質はエンジン単体テストでは検証できない。
