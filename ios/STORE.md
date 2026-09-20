# App Store に入れる文言

そのままコピーして貼れる形にしてある。文字数はすべて上限内で確認済み。

---

## 名前（上限30）

```
DOT DROP
```

**空いているか先に確認する。**取れなければ `DOT DROP - ドットを弾く` のように足す
（名前に説明を足すのは Apple も認めている。ただし「無料」「セール」などは不可）。

## サブタイトル（上限30）

```
引いて、はなす。ドットを弾ませる
```

控え案：
- `落として、弾ませて、増やす`
- `ドットをすべて赤くする`

## プロモーションテキスト（上限170）

**審査なしでいつでも書き換えられる。**更新のお知らせに使うとよい。

```
どこからでも引っ張って、はなす。ドットに当たるほど音が上がり、100点ごとに数字が飛び込む。広告も課金も通信もありません。オフラインでそのまま遊べます。
```

## 説明（上限4000）

```
玉を弾いて、ドットに当てる。それだけのゲームです。

画面のどこからでも引っ張って、はなす。引いた方向の反対へ玉が飛びます。
強さは5段階。引くほど音が上がるので、目を離していても手で分かります。

■ 赤い四角に当たると強くはね返る
● 青い円は玉を少しつかまえて、思わぬ方へ放す
▲ 黄色い三角に当たると、玉が3つに分かれる。分かれた玉がまた当たれば、さらに増える

下を流れる枠に落ちると点が入ります。×5 のところは大きいけれど、その隣は玉が減る。
枠は流れているので、どこに入るかは半分うで前、半分運です。

当て続けると音がどんどん上に登っていき、100点ごとに大きな数字が飛び込みます。
ポイントが溜まるとフィーバー。点は2倍、玉は減らず、画面ぜんぶが黄色に変わります。

そして、ひとつの台のドットを1本残らず赤くすると PERFECT。
これは1回では届きません。6回かけて塗っていって、ようやく出ます。

6回打つごとに台が変わり、だんだん厳しくなります。玉が尽きたら終わりです。

——

・広告はありません
・課金はありません
・インターネットに接続しません。機内モードでも遊べます
・記録は端末の中だけに残ります

・音、振動、点滅と揺れは、それぞれ切れます（右上の歯車から）
・遊び方は「あそびかた」で8つ、実際にやりながら覚えられます
・片手で遊べます
```


## キーワード（上限100・カンマ区切り・スペース不要）

```
ピンボール,ひまつぶし,暇つぶし,片手,オフライン,広告なし,ドット,ハイスコア,アーケード,ミニゲーム,シンプル,無料
```

名前とサブタイトルに入っている語は入れなくてよい（二重に効かない）。

## バージョン 1.0.0 の「このバージョンの新機能」

初回リリースなので、次の1行でよい。

```
はじめてのリリースです。
```

---

## URL

- **サポート URL**（必須）
  `https://snaproom1992.github.io/dotdrop/support.html`
- **プライバシーポリシー URL**（必須）
  `https://snaproom1992.github.io/dotdrop/privacy.html`
- **マーケティング URL**（任意）
  `https://snaproom1992.github.io/dotdrop/`

---

## App のプライバシー

「データを収集していません（Data Not Collected）」を選ぶ。
何も集めず、何も送らず、記録は端末の中だけなので、これで正しい。

## 年齢制限

質問はすべて「なし」。暴力・性的表現・ギャンブル・ユーザー間交流・
位置情報・外部リンク、どれも該当しない。**4+** になるはず。

**ギャンブルの項目は「なし」。**賭けも換金も無いので「シミュレートされたギャンブル」には
当たらない。**そう見られる言葉を自分から使わないこと。**「スマートボール」「パチンコ」は
店の文言にもキーワードにも入れない（賭け事を連想させ、年齢区分にも響きうる）。

## カテゴリ

第1 ゲーム＞アーケード ／ 第2 ゲーム＞カジュアル

---

## スクリーンショット（6.9インチが必須）

5枚。**上に短い見出しを載せる**と伝わる。文字はこげ茶の帯にクリームで。

1. タイトル画面 … `引いて、はなす`
2. 引いているところ（弧が5本出ている） … `強さは5段階`
3. ▲で玉が分かれた瞬間 … `▲に当たると、3つに分かれる`
4. 数字ドンが出ているところ … `100点ごとに、数字が飛び込む`
5. フィーバー中（画面が黄色） … `フィーバーは2倍。玉も減らない`

余裕があれば6枚目に結果画面（`記録は端末の中だけに残ります`）。

**撮るときは記録を入れてから。**空のままだときろくや結果画面が寂しい。

### 寸法（ここを間違えると弾かれる）

| | 寸法 | ファイル |
|---|---|---|
| スクリーンショット 6.9インチ | **1320×2868** | `6.9/<言語>/*.png` |
| スクリーンショット 6.5インチ | 1284×2778 | `6.5/<言語>/*.png` |
| **アプリプレビュー（動画）** | **886×1920** | `6.9/<言語>/preview.mp4` |

**動画だけ寸法が違う。**録画そのまま（`demo.mov`＝1320×2868）を入れると
「プレビューの寸法が正しくありません」と出る。`preview.mp4` のほうを使うこと。

プレビューは**任意**。静止画だけで審査に出せるので、迷ったら後回しでよい。

---

# English (U.S.)

App Store Connect で「英語（米国）」のローカリゼーションを足して、ここを貼る。
**アプリ自体も端末の言語が英語なら英語で動く**（`Localizable.xcstrings`）。

## Name (max 30)

```
DOT DROP
```

## Subtitle (max 30)

```
Pull, release, bounce the dots
```

控え案：
- `Drop it. Bounce it. Grow it.`
- `Turn every dot red`

## Promotional text (max 170)

```
Pull from anywhere and let go. Every dot raises the pitch, and every 100 points throws a huge number across the screen. No ads, no purchases, no network. Plays offline.
```

## Description (max 4000)

```
Flick a ball and hit the dots. That is the whole game.

Pull from anywhere on the screen and let go. The ball flies the opposite way.
There are five power levels, and the pitch rises as you pull, so you can feel it without looking.

■ Red squares bounce the ball hard
● Blue circles hold the ball for a moment, then let it go somewhere you did not expect
▲ Yellow triangles split the ball into three. Split balls can split again

Land in the slots sliding along the bottom to score. The ×5 slot pays big, but the one next to it takes balls away.
The slots keep moving, so where you land is half skill, half luck.

Keep hitting and the notes climb higher and higher. Every 100 points, a huge number comes flying in.
Fill the gauge and FEVER starts: double points, no balls lost, and the whole screen turns yellow.

And if you turn every single dot on one board red, that is a PERFECT.
You will not get there in one shot. It takes all six shots on that board, and it still barely happens.

The board changes every six shots and gets harder as you go. When you run out of balls, the game ends.

——

・No ads
・No in-app purchases
・No internet connection. Plays in airplane mode
・Records stay on your device

・Sound, haptics, and flashing can each be turned off (gear icon, top right)
・Eight short lessons teach you by playing, not by reading
・One hand is enough
```

## Keywords (max 100, comma separated, no spaces)

```
pinball,arcade,onehanded,offline,noads,dots,highscore,minigame,casual,simple,free,bounce
```

## What's New in 1.0.0

```
First release.
```

## Screenshots

日本語と同じ5枚を、英語で撮ったものに差し替える。見出しも英語にする。

1. Title … `Pull and release`
2. Aiming (five arcs) … `Five levels of power`
3. ▲ splitting the ball … `Triangles split the ball in three`
4. A big number landing … `A huge number every 100 points`
5. FEVER (yellow screen) … `FEVER: double points, nothing lost`

撮影は `ios/tools/shots.sh` が日本語と英語の両方を出す（`shots/ja/` と `shots/en/`）。

## 訳で気をつけたこと

- **「スマートボール」「パチンコ」に当たる語は英語でも使わない**（`pachinko` は賭け事に
  結びつくので、キーワードにも説明にも入れない）。`pinball` は機械式ゲームとして通る
- 画面の中の言葉（STAGE / FEVER / NEW RECORD / CLEAR）はもともと英語なので、
  日本語版と英語版でスクショの見た目はほとんど変わらない
- 「受け皿」は英語で `slot`。「釘」は `dot`（プレイヤーに見える言葉は ■ ● ▲ だけ、
  という決めごとは英語でも同じ）
