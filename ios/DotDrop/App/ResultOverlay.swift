import SwiftUI

/// `#over.result` に対応
struct ResultOverlay: View {
    var session: GameSession
    var width: CGFloat
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var onRetry: () -> Void
    var onTitle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedScore = 0
    @State private var counted = false

    /// Web の `.bigscore { font-size: clamp(88px, 30vw, 150px) }`。
    /// 100pt 固定だと、本家より2割小さい
    private var bigScoreSize: Double {
        min(150, max(88, Double(width) * 0.30))
    }

    /// (文字, 赤いか)。1位は NEW RECORD（赤）、2位以下はマスタードの「◯位」
    private var rankBadge: (String, Bool)? {
        if session.rank == 0, session.rankingTop.count > 1 { return ("NEW RECORD", true) }
        if session.rank >= 0 { return ("\(session.rank + 1)位", false) }
        if session.beatBest { return ("NEW RECORD", true) }
        return nil
    }

    /// 見出し＋中身。Web の `.res-sec`
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DD.bold(12))
                .tracking(0.48)
                .foregroundStyle(DD.paper.opacity(0.6))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }

    /// 上位5件。今回の回はマスタードで塗って、どれが自分か分かるようにする
    private var ranking: some View {
        VStack(spacing: 0) {
            if session.rankingTop.isEmpty {
                Text("まだ記録がありません")
                    .font(DD.regular(13))
                    .foregroundStyle(DD.paper.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
            } else {
                ForEach(Array(session.rankingTop.prefix(5).enumerated()), id: \.offset) { i, r in
                    let me = r == session.currentEntry
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1)")
                            .font(DD.bold(14))
                            .opacity(0.7)
                            .frame(width: 28, alignment: .leading)
                        Text("\(r.score)")
                            .font(DD.bold(20))
                            .kerning(-0.6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("ステージ\(r.stage)・\(month(r.date))/\(day(r.date))")
                            .font(DD.regular(11))
                            .opacity(0.7)
                    }
                    .foregroundStyle(me ? DD.ink : DD.paper)
                    .padding(.vertical, 7)
                    .padding(.horizontal, me ? 6 : 0)
                    .background(me ? DD.mustard : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: me ? 4 : 0))
                    .overlay(alignment: .top) {
                        if !me { Rectangle().fill(DD.paper.opacity(0.14)).frame(height: 1) }
                    }
                }
            }
        }
    }

    /// 2列。更新したものにはマスタードの「更新」を出す
    private var recordGrid: some View {
        let items = DDStore.recordLabels.filter { (session.records[$0.key] ?? 0) > 0 }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.key) { item in
                let isNew = session.newRecordKeys.contains(item.key)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(session.records[item.key] ?? 0)")
                        .font(DD.bold(22))
                        .kerning(-0.66)
                        .foregroundStyle(DD.paper)
                    Text(item.label)
                        .font(DD.regular(11))
                        .foregroundStyle(DD.paper.opacity(0.65))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isNew ? DD.mustard.opacity(0.18) : DD.paper.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if isNew {
                        Text("更新")
                            .font(DD.bold(10))
                            .foregroundStyle(DD.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DD.mustard)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(8)
                    }
                }
            }
        }
    }

    private func month(_ d: Date) -> Int { Calendar.current.component(.month, from: d) }
    private func day(_ d: Date) -> Int { Calendar.current.component(.day, from: d) }

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

                Text("\(displayedScore)")
                    .font(DD.bold(bigScoreSize))
                    .monospacedDigit()
                    .kerning(-bigScoreSize * 0.06)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(DD.paper)
                    .frame(height: bigScoreSize * 0.9)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(session.engine.stage + 1)")
                            .font(DD.bold(30))
                            .monospacedDigit().kerning(-1.2).frame(height: 30)
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
                        Text("\(session.gameBestShot)")
                            .font(DD.bold(30))
                            .monospacedDigit().kerning(-1.2).frame(height: 30)
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(Capsule().stroke(DD.paper.opacity(0.35), lineWidth: 1.5))
                }
                .padding(.top, 14)

                section("ランキング") { ranking }
                section("これまでの記録") { recordGrid }

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
    @AppStorage("dotdrop-sound") private var soundEnabled = true
    @AppStorage("dotdrop-haptics") private var hapticsEnabled = true
    @AppStorage("dotdrop-calm-effects") private var calmEffects = false
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
        .onChange(of: soundEnabled) { _, enabled in
            if !enabled { GameAudio.shared.suspend() }
        }
        .onChange(of: hapticsEnabled) { _, enabled in
            if !enabled { GameHaptics.cancel() }
        }
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

            DisclosureGroup("音・振動・演出") {
                Toggle("サウンド", isOn: $soundEnabled)
                Toggle("振動", isOn: $hapticsEnabled)
                Toggle("点滅・揺れを抑える", isOn: $calmEffects)
            }
            .font(DD.regular(13)).foregroundStyle(DD.paper)
            .tint(DD.mustard).padding(.top, 10)
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
