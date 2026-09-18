import SwiftUI

/// `#over.result` に対応
struct ResultOverlay: View {
    var session: GameSession
    var onRetry: () -> Void
    var onTitle: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if session.beatBest {
                    Text("NEW RECORD")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.66)
                        .foregroundStyle(DD.paper)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DD.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(.top, 8)
                }

                Text("総合スコア")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DD.paper.opacity(0.7))
                    .padding(.top, 26)

                Text("\(session.score)")
                    .font(.system(size: 100, weight: .bold))
                    .tracking(-6)
                    .foregroundStyle(DD.paper)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    VStack {
                        Text("\(session.engine.stage + 1)")
                            .font(.system(size: 30, weight: .bold))
                        Text("ステージ")
                            .font(.system(size: 11))
                            .opacity(0.6)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(DD.paper.opacity(0.2))
                        .frame(width: 1.5)
                    VStack {
                        Text("\(session.gameBestShot)")
                            .font(.system(size: 30, weight: .bold))
                        Text("1回の最高")
                            .font(.system(size: 11))
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

                Button(action: onRetry) {
                    Text("もう一度")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DD.paper)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        .background(DD.red)
                        .clipShape(Capsule())
                }
                .padding(.top, 30)

                Button(action: onTitle) {
                    Text("タイトルへ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DD.paper)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
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
struct ResetSheet: View {
    var session: GameSession
    var onReset: () -> Void
    var onTitle: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x1C1716).opacity(0.74)
                .ignoresSafeArea()
                .onTapGesture { session.showResetSheet = false }

            VStack(spacing: 0) {
                Capsule()
                    .fill(DD.paper.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)

                Text("リセットしますか？")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DD.paper)
                    .padding(.top, 14)

                Text("いまのスコアはランキングに残りません")
                    .font(.system(size: 12))
                    .foregroundStyle(DD.paper.opacity(0.6))
                    .padding(.top, 7)

                Button(action: onReset) {
                    Text("リセット")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DD.paper)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 16)
                        .background(DD.red)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)

                Button(action: onTitle) {
                    Text("タイトルに戻る")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DD.paper)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 10)
                        .overlay(Capsule().stroke(DD.paper.opacity(0.35), lineWidth: 1.5))
                }
                .padding(.top, 14)

                Button {
                    session.showResetSheet = false
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DD.paper.opacity(0.6))
                        .padding(.vertical, 15)
                }
                .padding(.top, 4)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity)
            .background(DD.brown)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
