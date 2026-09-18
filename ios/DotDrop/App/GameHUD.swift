import SwiftUI
import DotDropEngine

/// `<header>` — CSS の配置をそのまま
struct GameHUD: View {
    @ObservedObject var session: GameSession
    var safeTop: CGFloat

    var body: some View {
        let fever = session.fever
        let fg = DD.fg(fever: fever)

        ZStack(alignment: .top) {
            // #quitBtn — まんなか上
            Button {
                session.showResetSheet = true
            } label: {
                Text("リセット")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(9.5 * 0.08)
                    .foregroundStyle(fg.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .overlay(
                        Capsule().stroke(fg.opacity(0.45), lineWidth: 1.2)
                    )
            }
            .padding(.top, safeTop + 8)

            // #best — 右上
            HStack {
                Spacer()
                Group {
                    if session.beatBest {
                        Text("NEW RECORD")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.06 * 11)
                            .foregroundStyle(DD.paper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DD.red)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else if session.personalBest > 0 {
                        Text("自己ベスト \(session.personalBest)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(fg.opacity(0.75))
                    }
                }
                .frame(height: 15)
                .padding(.trailing, 20)
                .padding(.top, safeTop + 9)
            }

            // 持ち玉 / STAGE / スコア — padding top = safe + 38
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session.money)")
                        .font(.system(size: 46, weight: .bold))
                        .tracking(-46 * 0.05)
                        .foregroundStyle(fg)
                    Text("持ち玉")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(fg.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 1) {
                    Text("STAGE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(10 * 0.12)
                        .foregroundStyle(fg.opacity(0.6))
                    Text("\(session.engine.stage + 1)")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-22 * 0.04)
                        .foregroundStyle(fg)
                    HStack(spacing: 4) {
                        ForEach(0..<session.engine.config.shotsPerBoard, id: \.self) { i in
                            Circle()
                                .fill(i < session.boardShots ? DD.red : fg.opacity(0.2))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.top, 3)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.score)")
                        .font(.system(size: 46, weight: .bold))
                        .tracking(-46 * 0.05)
                        .foregroundStyle(fg)
                    Text("スコア")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(fg.opacity(0.65))
                    HStack(spacing: 6) {
                        Text(session.fever ? "残り\(session.feverLeft)" : "FEVER")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(9 * 0.12)
                            .foregroundStyle(fg.opacity(0.5))
                        gauge
                    }
                    .padding(.top, 6)
                    .opacity(session.banner != nil ? 0 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, safeTop + 38)
        }
        .allowsHitTesting(true)
    }

    private var gauge: some View {
        let fever = session.fever
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(fever ? DD.ink.opacity(0.18) : DD.paper.opacity(0.16))
                .frame(width: 58, height: 5)
            if fever {
                // 3分割の仕切り
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(i < session.feverLeft ? DD.ink : Color.clear)
                            .frame(width: 58 / 3, height: 5)
                    }
                }
                // 仕切り線
                HStack {
                    Spacer().frame(width: 58 / 3 - 1.5)
                    Rectangle().fill(DD.mustard).frame(width: 3, height: 5)
                    Spacer().frame(width: 58 / 3 - 3)
                    Rectangle().fill(DD.mustard).frame(width: 3, height: 5)
                    Spacer()
                }
            } else {
                Capsule()
                    .fill(DD.mustard)
                    .frame(width: 58 * session.feverProgress, height: 5)
            }
        }
        .frame(width: 58, height: 5)
        .clipShape(Capsule())
    }
}
