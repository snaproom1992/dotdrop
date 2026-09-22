# 審査への返信（ガイドライン 2.1 - Information Needed）

初回提出でほぼ必ず来る定型の問い合わせ。**却下ではない。**
App Store Connect の「アプリ審査情報」→ メモ欄に貼り、返信にも同じものを送る。

**英語で書く。**審査担当は英語圏のことが多く、日本語だと確認に時間がかかる。

---

## そのまま貼る文（English）

```
Thank you for reviewing DOT DROP. Here is the information you requested.

1) DEMO VIDEO
A screen recording made on a physical iPhone, starting from app launch and
showing a full play session, is attached to this reply.
The app has no account registration, no login, no user-generated content,
and no paid content, so those flows do not exist and are not in the video.

2) PURPOSE AND AUDIENCE
DOT DROP is a single-player arcade game. The player pulls anywhere on the
screen and releases to flick a ball, which bounces off dots, squares,
circles and triangles on the board and lands in one of the moving slots at
the bottom to score. The goal is to beat your own high score before you run
out of balls.
It is for anyone looking for a short, one-handed game. A round takes about
two minutes. There is no time pressure, no text to read, and no account to
make. Eight short built-in lessons teach the rules by playing rather than
by reading.

3) HOW TO ACCESS THE FEATURES
No login and no demo account are required. Everything is available
immediately on first launch.
- "はじめる" (PLAY) on the title screen starts a game.
- "あそびかた" (HOW TO PLAY) opens eight short lessons.
- The trophy icon (top left) opens records and the leaderboard.
- The gear icon (top right) turns sound, haptics and flashing on or off.
Game Center sign-in is optional. If the reviewer declines or ignores the
Game Center prompt, every part of the app still works; only the world
leaderboard is unavailable, and the app says so on screen.

4) EXTERNAL SERVICES
Apple Game Center (GameKit) only, used for a single leaderboard
("High Score", com.snaproom.dotdrop.highscore) and nothing else.
There are no third-party SDKs, no analytics, no advertising, no payment
processing, no AI services and no data providers. The app contains no
networking code of its own and makes no requests to any server we operate.
We do not operate a server. All gameplay and all records work fully offline;
the app can be played end to end in airplane mode.

5) REGIONAL DIFFERENCES
None. The app behaves identically in every region. It is localized in
Japanese and English, chosen automatically from the device language, and
the content and features are the same in both.

6) REGULATED INDUSTRIES / THIRD-PARTY MATERIAL
Not applicable. The app is not in a regulated industry and contains no
third-party protected material. All code, graphics, sound and music were
created by us. All sound is synthesized at runtime; there are no audio
files. There is no gambling, no wagering, no simulated gambling and no
prizes of any kind.
```

## 日本語（自分用の控え。貼るのは上の英語）

1. 実機で撮った、起動からの操作動画を添付
2. 1人用のアーケードゲーム。引いてはなして玉を弾き、下の受け皿に入れて点を取る。
   片手で2分。読む文章も、作るアカウントも無い
3. ログイン不要。デモアカウント不要。**Game Center を断っても全機能が使える**
4. 外部サービスは Apple の Game Center だけ。第三者SDK・解析・広告・決済・AI は無し。
   自前のサーバーも通信コードも無い。機内モードで最後まで遊べる
5. 地域差なし。日本語と英語（端末の言語で自動）。中身は同じ
6. 規制業種でない。第三者の素材なし。音は全部その場で合成。賭け事の要素なし

---

## 動画の撮り方（**実機で撮ること**）

シミュレータの録画（`shots/6.9/*/demo.mov`）は**使えない**。
Apple は「最新のOSを載せた実機で撮ったもの」と指定している。

1. iPhone の 設定 → コントロールセンター → **画面収録** を追加
2. コントロールセンターから録画を開始
3. **アプリを起動するところから**撮る（ホーム画面でアイコンを押す）
4. タイトル → はじめる → 2〜3分ふつうに遊ぶ → 玉切れ → 結果画面
5. きろく（トロフィー）と設定（歯車）も一度ずつ開く
6. 録画を止めて、返信に添付する

**長さは2〜3分でよい。**編集も字幕も要らない。

## 次の提出で気をつけること

- **スクリーンショットは「遊んでいるところ」を先に。**ガイドライン2.3.3 で
  「タイトルアートやスプラッシュだけではだめ」と名指しされている。
  1枚目をタイトル画面にしない（play / fever / split を前に出す）
- **提出前に TestFlight で実機を通しで遊ぶ。**2.1 のクラッシュで落ちると、
  今度は本当の却下になる
