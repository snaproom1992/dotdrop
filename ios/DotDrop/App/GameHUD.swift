import SwiftUI
import DotDropEngine

/// `<header>` — CSS の absolute 配置を再現（STAGE を flex に混ぜない）
struct GameHUD: View {
    var session: GameSession
    var safeTop: CGFloat
    var width: CGFloat

    /// 桁が増えても、まんなかの STAGE とぶつからない大きさまで落とす（Web の `Roller.fit()`）
    private func statSize(_ value: Int) -> Double {
        DD.statSize(digits: String(max(0, value)).count, screenWidth: Double(width))
    }

    /// 数字1つ。**`tracking` ではなく `kerning` を使うこと。**
    /// `tracking` は最後の文字のうしろにも詰めを入れるので、右端の数字が欠ける
    private func statNumber(_ value: Int) -> some View {
        let size = statSize(value)
        return Text("\(value)")
            .font(DD.bold(size))
            .kerning(-size * 0.05)
            .lineLimit(1)
            .fixedSize()
            .frame(height: size * 0.9, alignment: .center)
    }

    var body: some View {
        let fever = session.fever
        let fg = DD.fg(fever: fever)

        ZStack(alignment: .top) {
            // 持ち玉 ← → スコア（STAGE はここに入れない＝web の flex と同じ）
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    statNumber(session.moneyShown)
                        .scaleEffect(session.moneyBump ? 1.08 : 1, anchor: .leading)
                        .animation(.easeOut(duration: 0.12), value: session.moneyBump)
                    Text("持ち玉")
                        .font(DD.statLabel)
                        .padding(.top, 2)
                        .opacity(0.65)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    statNumber(session.scoreShown)
                        .scaleEffect(session.scoreBump ? 1.08 : 1, anchor: .trailing)
                        .animation(.easeOut(duration: 0.12), value: session.scoreBump)
                    Text("スコア")
                        .font(DD.statLabel)
                        .padding(.top, 2)
                        .opacity(0.65)
                    HStack(spacing: 6) {
                        Text(session.fever ? "残り\(session.feverLeft)" : "FEVER")
                            .font(DD.bold(9))
                            .tracking(1.08)
                            .opacity(0.5)
                        gauge
                    }
                    .padding(.top, 6)
                    .opacity(session.bannerUp ? 0 : 1)
                }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 20)
            .padding(.top, safeTop + 38)

            // .stage-hud — absolute center
            VStack(spacing: 0) {
                Text("STAGE")
                    .font(DD.bold(10))
                    .tracking(1.2)
                    .opacity(0.6)
                Text("\(session.engine.stage + 1)")
                    .font(DD.bold(22))
                    .tracking(-0.88)
                    .padding(.top, 1)
                HStack(spacing: 4) {
                    ForEach(0..<session.engine.config.shotsPerBoard, id: \.self) { i in
                        Circle()
                            .fill(i < session.boardShots ? DD.red : fg.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.top, 3)
            }
            .foregroundStyle(fg)
            .padding(.top, safeTop + 38)

            // #quitBtn — absolute center, safer than STAGE
            Button {
                session.showResetSheet = true
            } label: {
                Text("リセット")
                    .font(DD.bold(9.5))
                    .tracking(0.76)
                    .foregroundStyle(fg.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(fg.opacity(0.45), lineWidth: 1.2))
            }
            .padding(.top, safeTop + 8)

            // #best — absolute right
            HStack {
                Spacer()
                Group {
                    if session.beatBest {
                        Text("NEW RECORD")
                            .font(DD.bold(11))
                            .tracking(0.66)
                            .foregroundStyle(DD.paper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DD.red)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else if session.personalBest > 0 {
                        Text("自己ベスト \(session.personalBest)")
                            .font(DD.regular(11))
                            .foregroundStyle(fg.opacity(0.75))
                    }
                }
                .frame(height: 15, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.top, safeTop + 9)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(true)
    }

    private var gauge: some View {
        let fever = session.fever
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(fever ? DD.ink.opacity(0.18) : DD.paper.opacity(0.16))
                .frame(width: 58, height: 5)
            if fever {
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(i < session.feverLeft ? DD.ink : Color.clear)
                            .frame(width: 58 / 3, height: 5)
                    }
                }
                HStack(spacing: 0) {
                    Color.clear.frame(width: 58 / 3 - 1.5)
                    Rectangle().fill(DD.mustard).frame(width: 3, height: 5)
                    Color.clear.frame(width: 58 / 3 - 3)
                    Rectangle().fill(DD.mustard).frame(width: 3, height: 5)
                    Spacer(minLength: 0)
                }
            } else {
                Capsule()
                    .fill(DD.mustard)
                    .frame(width: max(0, 58 * session.feverProgress), height: 5)
            }
        }
        .frame(width: 58, height: 5)
        .clipShape(Capsule())
    }
}
