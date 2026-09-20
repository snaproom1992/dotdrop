# リリースの準備

App Store に出すまでにやること。**済んだら印をつける。**

## コード側（済み）

- [x] **プライバシーマニフェスト**（`Resources/PrivacyInfo.xcprivacy`）
      **これが無いとアップロードで弾かれる。**何も集めていなくても、`UserDefaults` は
      「理由の申告が要る API」なので、使う理由（CA92.1）を書く必要がある
- [x] **暗号化の申告**（`ITSAppUsesNonExemptEncryption = NO`）。書き出しのたびに
      聞かれるのを止める。このアプリは通信も暗号化もしない
- [x] バージョンを `1.0.0` に
- [x] 縦向き固定・ステータスバー非表示・起動画面
- [x] アプリアイコン（1024の1枚。いまの Xcode はこれでよい）
- [x] プライバシーポリシーのページ（`privacy.html`。GitHub Pages でそのまま公開される）
      → https://snaproom1992.github.io/dotdrop/privacy.html
- [x] **英語対応**（`Resources/Localizable.xcstrings`）。端末の言語が英語なら英語で動く。
      アプリ内に切り替えは置かない

## 決めること（作者）

- [x] **バンドル ID** … `com.snaproom.dotdrop`
      **一度審査に出すと変えられない。**App Store Connect でもこの文字列で登録する
- [ ] **App Store に出す名前。**「DOT DROP」が取れるか要確認（世界で1つ）。
      取れなければサブタイトルで差をつけるか、名前を足す
- [ ] **カテゴリ。**第1 ゲーム＞アーケード ／ 第2 ゲーム＞カジュアル
- [ ] **年齢制限。**質問に答えるだけ。暴力も課金も通信も無いので 4+ になるはず。
      **ギャンブルの項目は「なし」**（賭けも換金もない）
- [ ] **出す国。**英語にも対応したので、日本だけに絞る理由はない（全世界のままでよい）

## 手を動かすこと（作者）

- [x] Apple Developer Program に登録（年 $99）
- [ ] **App ID を登録する。**developer.apple.com → Identifiers → ＋ → App IDs → App →
      Bundle ID は **Explicit** で `com.snaproom.dotdrop`。Capabilities は何も付けない
      - **Xcode の実機ビルドでは登録されない。**`XC Wildcard (*)` のプロファイルが
        使われてしまい、専用の ID が作られないため。手で登録するのが確実
      - これが済むまで App Store Connect の「新規アプリ」でバンドル ID を選べない
- [ ] App Store Connect でアプリを作る（プラットフォーム iOS ／ 名前 `DOT DROP` ／
      プライマリ言語 日本語 ／ SKU `dotdrop` ／ ユーザアクセス制限なし）
- [ ] **英語（米国）のローカリゼーションを足す。**`ios/STORE.md` の English の節を貼る
- [ ] **スクリーンショット。**6.9インチ（iPhone 16 Pro Max）が必須。
      **手で撮らなくてよい。**コミットメッセージに `[shots]` と書いて push するか、
      Actions から `iOS screenshots` を手で走らせる。日本語と英語の両方を撮る
      （`shots/ja/` と `shots/en/`：title / play / aim / fever / result / records / lessons ＋ demo.mov）。
      できたものは `shots-latest` ブランチに置かれるので、git でも取れる。
      Mac があるなら手元でも `ios/tools/shots.sh` で同じものが撮れる
- [ ] 説明文・キーワード・サポート URL（日本語と英語の両方。`ios/STORE.md`）
- [ ] Xcode から Archive → App Store Connect へアップロード
- [ ] TestFlight で自分の端末に入れて、最後に一度通しで遊ぶ
- [ ] 審査に提出

## 出す前に必ず見るところ

- [ ] **ふつうとフィーバー中の両方**で全画面を見る（色が背景と同じになる事故が何度も起きている）
- [ ] **日本語と英語の両方**で全画面を見る（英語は文が伸びる。いちばん伸びるのは
      あそびかたの一覧と、リセットの板）
- [ ] 端末3種（Dynamic Island / ノッチあり / ノッチなし）で、上の余白と釘の上端
- [ ] 音を切った状態・振動を切った状態でも遊べるか（設定で切れる）
- [ ] 「点滅・揺れを抑える」を入れた状態
- [ ] アプリを削除して入れ直し、記録が空の状態から始めてみる
      （きろくが空のときに「まだ記録がありません」と出るか）
- [ ] 機内モードで遊ぶ（通信していないことの確認）
