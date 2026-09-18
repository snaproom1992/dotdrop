import SwiftUI

/// `#over.result` に対応
struct ResultOverlay: View {
    var session: GameSession
    var width: CGFloat
    var onRetry: () -> Void
    var onTitle: () -> Void

    /// Web の `.bigscore { font-size: clamp(88px, 30vw, 150px) }`。
    /// 100pt 固定だと、本家より2割小さい
    private var bigScoreSize: Double {
        min(150, max(88, Double(width) * 0.30))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if session.beatBest {
                    Text("NEW RECORD")
                        .font(DD.bold(11))
                        .tracking(0.66)
                        .foregroundStyle(DD.paper)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DD.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(.top, 8)
                }

                Text("総合スコア")
                    .font(DD.bold(13))
                    .foregroundStyle(DD.paper.opacity(0.7))
                    .padding(.top, 26)

                Text("\(session.score)")
                    .font(DD.bold(bigScoreSize))
                    .kerning(-bigScoreSize * 0.06)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(DD.paper)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    VStack {
                        Text("\(session.engine.stage + 1)")
                            .font(DD.bold(30))
                        Text("ステージ")
                            .font(DD.regular(11))
                            .opacity(0.6)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(DD.paper.opacity(0.2))
                        .frame(width: 1.5)
                    VStack {
                        Text("\(session.gameBestShot)")
                            .font(DD.bold(30))
                        Text("1回の最高")
                            .font(DD.regular(11))
                            .opacity(0.6)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(DD.paper)
                .padding(.top, 22)
                .overlay(alignment: .top) {
                    Rectangle().fill(DD.paper.opacity(0.2)).frame(height: 1.5)
                }

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

                Spacer(minLength: 40)
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(DD.brown.ignoresSafeArea())
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

    private static let slideIn = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x1C1716)
                .opacity(shown ? 0.74 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            card
                .offset(y: shown ? drag : 600)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            drag = max(0, v.translation.height)
                            if drag > 6 { moved = true }
                        }
                        .onEnded { _ in
                            let far = drag > 70
                            withAnimation(Self.slideIn) { drag = 0 }
                            if far { close() }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { moved = false }
                        }
                )
        }
        .onAppear { withAnimation(Self.slideIn) { shown = true } }
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
            Button { tap { session.showResetSheet = false } } label: {
                Text("キャンセル")
                    .font(DD.bold(14))
                    .foregroundStyle(DD.paper.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .padding(.top, 4)
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
        action()
    }

    private func close() {
        withAnimation(Self.slideIn) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            session.showResetSheet = false
        }
    }
}
