import SwiftUI

/// `#over.result` に対応
struct ResultOverlay: View {
    @State private var rankScope: RankScope = .local
    var session: GameSession
    var width: CGFloat
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var onRetry: () -> Void
    var onTitle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedScore = 0
    @State private var counted = false

    /// 中身が入る幅（`.frame(maxWidth: 320)` と左右24の余白）
    private var contentWidth: Double { min(320, Double(width) - 48) }

    /// Web の `.bigscore { font-size: clamp(88px, 30vw, 150px) }`。
    /// **リールの1枠は .57em。**その物差しで、入る大きさまで落とす。
    /// 縮む任せ（minimumScaleFactor）にすると、測った幅と描く幅がずれて右端が欠ける
    private var bigScoreSize: Double {
        let cap = min(150, max(88, Double(width) * 0.30))
        let digits = Double(max(1, String(max(0, session.score)).count))
        return min(cap, (contentWidth - 4) / (digits * 0.57))
    }

    /// (文字, 赤いか)。1位は NEW RECORD（赤）、2位以下はマスタードの「◯位」
    private var rankBadge: (String, Bool)? {
        if session.rank == 0, session.rankingTop.count > 1 { return ("NEW RECORD", true) }
        if session.rank >= 0 { return (String(localized: "\(session.rank + 1)位"), false) }
        if session.beatBest { return ("NEW RECORD", true) }
        return nil
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1位なら NEW RECORD、それ以外で10位までに入ったら「◯位」
                ZStack {
                  if let badge = rankBadge {
                    Text(badge.0)
                        .font(DD.bold(11))
                        .tracking(0.66)
                        .foregroundStyle(badge.1 ? DD.paper : DD.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.1 ? DD.red : DD.mustard)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .opacity(counted ? 1 : 0)
                  }
                }
                .frame(height: 22)

                Text("総合スコア")
                    .font(DD.bold(13))
                    .kerning(0.52)
                    .foregroundStyle(DD.paper.opacity(0.7))
                    .padding(.top, 26)

                // **ゲーム中の持ち玉・スコアと同じリールで回す。**
                // ただの数字の差し替えだと、画面が変わっても同じ見せ方にならない
                RollingNumber(value: displayedScore, size: bigScoreSize)
                    .foregroundStyle(DD.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text(verbatim: "\(session.engine.stage + 1)")
                            .font(DD.bold(30))
                            .kerning(-1.2).frame(height: DD.lineBox(30) * 0.8)
                        Text("ステージ")
                            .font(DD.regular(11))
                            .opacity(0.6)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(DD.paper.opacity(0.2))
                        .frame(width: 1.5)
                    VStack(spacing: 0) {
                        Text(verbatim: "\(session.gameBestShot)")
                            .font(DD.bold(30))
                            .kerning(-1.2).frame(height: DD.lineBox(30) * 0.8)
                        Text("1回の最高")
                            .font(DD.regular(11))
                            .opacity(0.6)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(DD.paper)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle().fill(DD.paper.opacity(0.2)).frame(height: 1.5)
                }
                .padding(.top, 22)

                // 本家の `.result > * { width:100%; max-width:320px }`。
                // **2つのボタンは同じ幅にそろえる。**文字幅ぶんだけにすると幅が変わる
                Button(action: onRetry) {
                    Text("もう一度")
                        .font(DD.bold(18))
                        .foregroundStyle(DD.paper)
                        .frame(height: DD.lineBox(18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DD.red)
                        .clipShape(Capsule())
                }
                .padding(.top, 30)

                Button(action: onTitle) {
                    Text("タイトルへ")
                        .font(DD.bold(13))
                        .foregroundStyle(DD.paper)
                        .frame(height: DD.lineBox(13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(Capsule().stroke(DD.paper.opacity(0.35), lineWidth: 1.5))
                }
                .padding(.top, 14)

                RecordsSections(
                    scope: $rankScope,
                    entries: session.rankingTop,
                    records: session.records,
                    highlight: session.currentEntry,
                    newKeys: session.newRecordKeys,
                    limit: 5
                )

            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, safeTop + 40)
            .padding(.bottom, safeBottom + 40)
        }
        .background(DD.brown.ignoresSafeArea())
        .task(id: session.currentEntry?.date) {
            let target = session.score
            let duration = reduceMotion ? 0 : min(1.6, 0.4 + Double(target) * 0.002)
            let began = Date()
            counted = false
            while !Task.isCancelled {
                let p = duration == 0 ? 1 : min(1, Date().timeIntervalSince(began) / duration)
                displayedScore = Int((Double(target) * (1 - pow(1 - p, 3))).rounded())
                if p >= 1 { break }
                if Int(p * 100) % 4 == 0 {
                    GameAudio.shared.voice(freq: 1800 + p * 900, dur: 0.02, gain: 0.03, wave: .sine)
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { counted = true }
            GameAudio.shared.voice(freq: GameAudio.shared.note(5, fever: false), dur: 0.3, gain: 0.08)
            if session.rank == 0 {
                GameAudio.shared.playMilestone(level: min(10, max(3, target / 300)))
                GameHaptics.pattern(2, intervalMs: 85)
            }
        }
    }
}

/// `#sheet` リセット確認
/// 下から出る板。**「それらしい見た目」では足りない。**
/// 下から滑り出す／指についてくる／70px より下へ引いたら閉じる、まで入れて初めて
/// 「どうやって戻るのか」が分かる。逃げ道は3通り（下にスワイプ／キャンセル／板の外をタップ）
struct ResetSheet: View {
    var session: GameSession
    var safeBottom: CGFloat
    var onReset: () -> Void
    var onTitle: () -> Void

    @State private var shown = false
    @State private var drag: CGFloat = 0
    /// 6px 以上引いたら、指を離してもボタンを押したことにしない（引きながらの誤爆を防ぐ）
    @State private var moved = false
    @State private var closing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let slideIn = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x1C1716)
                .opacity(shown ? 0.74 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            card
                .offset(y: shown ? drag : 1_200)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            drag = max(0, v.translation.height)
                            if drag > 6 { moved = true }
                        }
                        .onEnded { _ in
                            let far = drag > 70
                            withAnimation(reduceMotion ? nil : Self.slideIn) { drag = 0 }
                            if far { close() }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { moved = false }
                        }
                )
        }
        .onAppear { withAnimation(reduceMotion ? nil : Self.slideIn) { shown = true } }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // つまみ。下へ引けることを形で示す
            Capsule()
                .fill(DD.paper.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            Text("リセットしますか？")
                .font(DD.bold(17))
                .foregroundStyle(DD.paper)
                .padding(.top, 14)

            Text("いまのスコアはランキングに残りません")
                .font(DD.regular(12))
                .foregroundStyle(DD.paper.opacity(0.6))
                .padding(.top, 7)

            Button { tap(onReset) } label: {
                Text("リセット")
                    .font(DD.bold(18))
                    .foregroundStyle(DD.paper)
                    .frame(height: DD.lineBox(18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DD.red)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)

            Button { tap(onTitle) } label: {
                Text("タイトルに戻る")
                    .font(DD.bold(13))
                    .foregroundStyle(DD.paper)
                    .frame(height: DD.lineBox(13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(DD.paper.opacity(0.35), lineWidth: 1.5))
            }
            .padding(.top, 14)

            // キャンセルは丸で囲わない。ただの文字にして、2つの操作と役割を分ける
            Button { tap({}) } label: {
                Text("キャンセル")
                    .font(DD.bold(14))
                    .foregroundStyle(DD.paper.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .padding(.top, 4)

            // **ここに設定を足さないこと。**板の中身は［見出し］［ひとこと］［リセット］
            // ［タイトルに戻る］［キャンセル］の5つ。キャンセルの下に別の操作が付くと
            // 板の終わりが分からなくなるし、「やめるかどうか」の場に別の用事が混ざる。
            // 音・振動・演出はタイトル画面の右上へ移した（SettingsSheet）
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        // 下は画面の端まで。ホームバーのぶんだけ中身を上げる
        .padding(.bottom, safeBottom + 26)
        .background(DD.brown)
        // 角を丸めるのは上だけ。下まで丸めると、浮いた札に見えて板にならない
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    /// 引いたあとの指離しでボタンが反応しないようにする
    private func tap(_ action: @escaping () -> Void) {
        guard !moved else { return }
        close(action)
    }

    private func close(_ action: @escaping () -> Void = {}) {
        guard !closing else { return }
        closing = true
        withAnimation(reduceMotion ? nil : Self.slideIn) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.24)) {
            session.showResetSheet = false
            action()
        }
    }
}
