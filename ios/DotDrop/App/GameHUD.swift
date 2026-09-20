import SwiftUI
import DotDropEngine

/// `<header>` — CSS の absolute 配置を再現（STAGE を flex に混ぜない）
struct GameHUD: View {
    var session: GameSession
    var safeTop: CGFloat
    var width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 数字に使える幅。画面の半分 −（まんなかの STAGE の半分25）− 32
    private var room: Double { max(30, Double(width) / 2 - (session.tutorial == nil ? 25 : 100) - 32) }

    /// 桁が増えても、まんなかの STAGE とぶつからない大きさまで落とす（Web の `Roller.fit()`）
    private func statSize(_ value: Int) -> Double {
        min(46, max(16, room / (Double(String(max(0, value)).count) * 0.57)))
    }

    /// Fixed-width digit cells; measure the visible digits for flyer destinations.
    private func statNumber(_ value: Int, _ alignment: Alignment) -> some View {
        let size = statSize(value)
        let key = alignment == .leading ? "money" : "score"
        return RollingNumber(value: value, size: size)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: HUDFramePreference.self,
                        value: [key: geo.frame(in: .named("board"))])
                }
            }
            .frame(maxWidth: room, alignment: alignment)
            .frame(height: size * 0.9, alignment: .center)
    }

    var body: some View {
        let fever = session.fever
        let fg = DD.fg(fever: fever)

        ZStack(alignment: .top) {
            // 持ち玉 ← → スコア（STAGE はここに入れない＝web の flex と同じ）
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    statNumber(session.moneyShown, .leading)
                        .scaleEffect(session.moneyBump ? 1.08 : 1, anchor: .leading)
                        .animation(.easeOut(duration: 0.12), value: session.moneyBump)
                    Text("持ち玉")
                        .font(DD.statLabel)
                        .padding(.top, 2)
                        .opacity(0.65)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    statNumber(session.scoreShown, .trailing)
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
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: session.bannerUp)
                }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 20)
            .padding(.top, safeTop + 38)

            if let step = session.tutorial {
                VStack(spacing: 4) {
                    Text("あそびかた \((session.tutorialIndex ?? 0) + 1) / 8")
                        .font(DD.bold(10)).opacity(0.6)
                    // フィーバー中も色が変わるので、文字は現在の前景色で描く（記号だけ元の色）
                    step.titleText(fg)
                        .font(DD.bold(17)).lineLimit(1).minimumScaleFactor(0.7)
                    Text(session.tutorialSucceeded ? "CLEAR" : "\(min(session.tutorialValue, step.target)) / \(step.target)")
                        .font(DD.bold(session.tutorialSucceeded ? 14 : 26))
                        .foregroundStyle(session.tutorialSucceeded ? DD.red : fg)
                }
                .foregroundStyle(fg).frame(width: 200).padding(.top, safeTop + 38)
            } else {
            // .stage-hud — absolute center
            VStack(spacing: 0) {
                Text("STAGE")
                    .font(DD.bold(10))
                    .tracking(1.2)
                    .opacity(0.6)
                Text(verbatim: "\(session.engine.stage + 1)")
                    .font(DD.bold(22))
                    .tracking(-0.88)
                    .padding(.top, 1)
                    // 本家の .stage-hud b.bump。持ち玉・スコア（1.08倍）より大きく跳ねる
                    .scaleEffect(session.stageBump ? 1.4 : 1)
                    .animation(.easeOut(duration: 0.2), value: session.stageBump)
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
            }

            // #quitBtn — absolute center, safer than STAGE
              Button {
                if session.tutorial != nil { session.openTutorialList() }
                else { session.showResetSheet = true }
            } label: {
                Text(session.tutorial == nil ? "リセット" : "一覧へ")
                    .font(DD.bold(9.5))
                    .tracking(0.76)
                    .foregroundStyle(fg.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(fg.opacity(0.45), lineWidth: 1.2))
            }
            .padding(.top, safeTop + 8)

            // #best — absolute right
            if session.tutorial == nil {
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
                        Text("自己ベスト \(String(session.personalBest))")
                            .font(DD.regular(11))
                            .foregroundStyle(fg.opacity(0.75))
                    }
                }
                .frame(height: 15, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.top, safeTop + 9)
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(true)
        .onPreferenceChange(HUDFramePreference.self) { frames in
            if let frame = frames["money"] { session.moneyFrame = frame }
            if let frame = frames["score"] { session.scoreFrame = frame }
        }
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: session.feverProgress)
    }
}

private struct HUDFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct RollingNumber: View {
    let value: Int
    let size: Double
    var body: some View {
        let digits = Array(String(max(0, value))).reversed().map { Int(String($0)) ?? 0 }
        HStack(spacing: 0) {
            ForEach(Array(digits.indices.reversed()), id: \.self) { place in
                RollingDigit(digit: digits[place], size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value)")
    }
}

private struct RollingDigit: View {
    let digit: Int
    let size: Double
    @State private var position: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(digit: Int, size: Double) {
        self.digit = digit; self.size = size
        _position = State(initialValue: Double(digit))
    }
    var body: some View {
        ReelFace(position: position, size: size)
            .frame(width: size * 0.57, height: size * 0.9)
            // **横は切らないこと。**セル幅 .57em に対して「4」の墨は .55em あり、
            // 中央に置いても端がぎりぎり。clipped() だと右端がわずかに欠ける。
            // 上下だけ切れば、隣の数字が見えるのを隠すという目的は果たせる
            .clipShape(Rectangle().scale(x: 1.6, y: 1))
            // 上下の端をわずかに抜いて、切り口の線を消す。
            // **抜けるのは外側7%まで。**枠は .9em、数字は .7em なので、
            // 余っているのは上下11%ずつしかない。深く抜くと数字自体が削れる
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.93),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onChange(of: digit) { _, next in
                let current = (Int(position.rounded()) % 10 + 10) % 10
                let forward = (next - current + 10) % 10
                let backward = (current - next + 10) % 10
                withAnimation(reduceMotion ? nil : .timingCurve(0.3, 1.5, 0.5, 1, duration: 0.18)) {
                    position += Double(forward <= backward ? forward : -backward)
                }
            }
    }
}

private struct ReelFace: View, Animatable {
    var position: Double
    let size: Double
    var animatableData: Double {
        get { position }
        set { position = newValue }
    }
    var body: some View {
        Canvas { ctx, bounds in
            // セルの高さは size*0.9。ずれが1セルを超えるものは完全に外なので描かない
            let first = Int(floor(position))
            for n in first...(first + 1) {
                let digit = (n % 10 + 10) % 10
                // 枠の中心からどれだけずれているか（0＝ぴたり、1＝1枠ぶん外）
                let off = abs(Double(n) - position)
                let text = ctx.resolve(Text(verbatim: "\(digit)").font(DD.bold(size)))
                var layer = ctx
                // **ずれている数字ほど薄く、そしてぼかす。**
                // 止まっているときは off が 0 なのでそのまま。回っている間だけ効く。
                // 上下を一律にぼかすと止まった数字までにじむので、動いた量で決める
                if off > 0.02 {
                    layer.opacity = max(0, 1 - off * 0.85)
                    layer.addFilter(.blur(radius: min(size * 0.05, off * size * 0.07)))
                }
                layer.draw(
                    text,
                    at: CGPoint(x: bounds.width / 2, y: bounds.height / 2 + (Double(n) - position) * size * 0.9),
                    anchor: .center
                )
            }
        }
    }
}
