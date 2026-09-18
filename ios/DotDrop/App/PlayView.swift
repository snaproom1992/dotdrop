import SwiftUI
import DotDropEngine

/// フリープレイ（物理は Engine のまま。描画・進行のみ）
struct PlayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = PlaySession()

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let usableH = geo.size.height
            // Web の fit() に近い：画面に収まる論理高さ
            let targetLH = max(620.0, min(780.0, usableH / max(geo.size.width / Engine.logicalWidth, 0.01)))
            let scale = min(geo.size.width / Engine.logicalWidth, usableH / session.engine.logicalHeight)
            let boardW = Engine.logicalWidth * scale
            let boardH = session.engine.logicalHeight * scale
            let origin = CGPoint(
                x: (geo.size.width - boardW) / 2,
                y: (usableH - boardH) / 2
            )

            ZStack {
                session.palette.bg.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { ctx, size in
                        session.ensureHeight(targetLH)
                        session.tick(now: timeline.date)
                        BoardRenderer.draw(
                            ctx: ctx,
                            origin: origin,
                            scale: scale,
                            boardH: boardH,
                            screenH: size.height,
                            session: session
                        )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard session.canShoot else { return }
                                // Web と同じ：押し始めからの相対移動
                                let dx = value.translation.width / scale
                                let dy = value.translation.height / scale
                                session.setPull(dx: dx, dy: dy)
                            }
                            .onEnded { _ in
                                session.releasePull()
                            }
                    )
                }

                // HUD
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(session.ballsLeft)")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundStyle(session.palette.ink)
                            Text("持ち玉")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(session.palette.ink.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 4) {
                            Button {
                                dismiss()
                            } label: {
                                Text("リセット")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(session.palette.ink.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .overlay(
                                        Capsule().stroke(session.palette.ink.opacity(0.35), lineWidth: 1.5)
                                    )
                            }
                            Text("STAGE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(session.palette.ink.opacity(0.45))
                            Text("\(session.engine.stage + 1)")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(session.palette.ink)
                            HStack(spacing: 5) {
                                ForEach(0..<session.engine.config.shotsPerBoard, id: \.self) { i in
                                    Circle()
                                        .fill(i < session.boardShots ? Color(hex: 0xD7141F) : session.palette.ink.opacity(0.2))
                                        .frame(width: 7, height: 7)
                                }
                            }
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(session.score)")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundStyle(session.palette.ink)
                            Text("スコア")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(session.palette.ink.opacity(0.45))
                            HStack(spacing: 6) {
                                Text(session.engine.fever ? "残り\(session.feverLeft)" : "FEVER")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(session.palette.ink.opacity(0.5))
                                FeverGauge(
                                    progress: session.feverGaugeProgress,
                                    fever: session.engine.fever,
                                    segments: session.engine.config.feverShots,
                                    left: session.feverLeft,
                                    ink: session.palette.ink
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(8, safeTop - 20))

                    Spacer()
                }

                if let banner = session.banner {
                    BannerView(banner: banner, fever: session.engine.fever)
                        .padding(.top, safeTop + 72)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }

                if session.gameOver {
                    GameOverOverlay(
                        score: session.score,
                        stage: session.engine.stage + 1,
                        onRetry: { session.resetBoard() },
                        onTitle: { dismiss() }
                    )
                }
            }
            .onAppear {
                session.ensureHeight(targetLH)
                session.resetBoard()
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// MARK: - Palette / UI bits

struct PlayPalette {
    var bg: Color
    var ink: Color
    var dim: Color
    var peg: Color
    var ball: Color
    var floor: Color
}

struct BannerData {
    var word: String
    var sub: String
    var color: Color
    var born: Date
}

struct BannerView: View {
    let banner: BannerData
    let fever: Bool
    var body: some View {
        let ink: Color = fever || banner.color == Color(hex: 0xF2F1EE) || banner.color == Color(hex: 0xEAA83A) || banner.color == Color(hex: 0xD7141F)
            ? Color(hex: 0x1C1716) : Color(hex: 0xF2F1EE)
        HStack(alignment: .center, spacing: 12) {
            Text(banner.word)
                .font(.system(size: 28, weight: .heavy))
            Rectangle()
                .fill(ink.opacity(0.28))
                .frame(width: 1.5, height: 28)
            Text(banner.sub)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(banner.color)
        .padding(.horizontal, 0)
    }
}

struct FeverGauge: View {
    var progress: CGFloat
    var fever: Bool
    var segments: Int
    var left: Int
    var ink: Color
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(ink.opacity(0.18)).frame(width: 58, height: 6)
            if fever {
                HStack(spacing: 2) {
                    ForEach(0..<segments, id: \.self) { i in
                        Capsule()
                            .fill(i < left ? ink : ink.opacity(0.15))
                            .frame(width: (58 - CGFloat(segments - 1) * 2) / CGFloat(segments), height: 6)
                    }
                }
            } else {
                Capsule()
                    .fill(Color(hex: 0xEAA83A))
                    .frame(width: 58 * min(1, progress), height: 6)
            }
        }
    }
}

struct GameOverOverlay: View {
    var score: Int
    var stage: Int
    var onRetry: () -> Void
    var onTitle: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("\(score)")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(Color(hex: 0xF2F1EE))
                Text("ステージ \(stage)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF2F1EE).opacity(0.55))
                Button(action: onRetry) {
                    Text("もう一度")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(hex: 0xF2F1EE))
                        .frame(width: 220, height: 56)
                        .background(Color(hex: 0xD7141F))
                        .clipShape(Capsule())
                }
                Button(action: onTitle) {
                    Text("タイトルへ")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF2F1EE))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 14)
                        .overlay(Capsule().stroke(Color(hex: 0xF2F1EE).opacity(0.45), lineWidth: 2))
                }
            }
            .padding(28)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Board draw

enum BoardRenderer {
    static func draw(
        ctx: GraphicsContext,
        origin: CGPoint,
        scale: CGFloat,
        boardH: CGFloat,
        screenH: CGFloat,
        session: PlaySession
    ) {
        let e = session.engine
        let pal = session.palette
        let top = e.slotTop()

        // 受け皿
        let slotW = Engine.slotWidth
        let convLen = e.conveyorLength
        for i in 0..<e.config.slotM.count {
            var u = (Double(i) * slotW + e.conveyor).truncatingRemainder(dividingBy: convLen)
            if u < 0 { u += convLen }
            var x = u
            if x > Engine.logicalWidth + slotW { x -= convLen }
            if x < -slotW || x > Engine.logicalWidth { continue }
            let info = e.slotInfo(i)
            let (fill, fg) = slotColors(m: info.m, b: info.b, fever: e.fever)
            let sx = origin.x + x * scale
            let sy = origin.y + (top + 6) * scale
            let sw = (slotW - 4) * scale
            let sh = max(screenH - sy + 20, 40)
            let rect = CGRect(x: sx + 2 * scale, y: sy, width: sw, height: sh)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 6 * scale), with: .color(fill))

            let cx = sx + slotW / 2 * scale
            ctx.draw(
                Text("×\(info.m)").font(.system(size: 16 * scale, weight: .heavy)).foregroundColor(fg),
                at: CGPoint(x: cx, y: origin.y + (top + 28) * scale),
                anchor: .center
            )

            if info.b > 0 {
                for j in 0..<info.b {
                    let ox = (Double(j) - Double(info.b - 1) / 2) * 11
                    let p = CGPoint(x: cx + ox * scale, y: origin.y + (top + 50) * scale)
                    let r = 3.5 * scale
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(fg))
                }
            } else if info.b < 0 {
                let n = -info.b
                for j in 0..<n {
                    let ox = (Double(j) - Double(n - 1) / 2) * 14
                    let p = CGPoint(x: cx + ox * scale, y: origin.y + (top + 50) * scale)
                    let r = 5 * scale
                    let path = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    ctx.stroke(path, with: .color(fg), style: StrokeStyle(lineWidth: 1.5 * scale, dash: [3 * scale, 3 * scale]))
                }
            }
        }

        // 釘
        for p in e.pegs {
            let c = CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
            switch p.kind {
            case .square:
                let s = Engine.squareHalf * 2 * scale
                let r = CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
                ctx.fill(Path(r), with: .color(Color(hex: 0xD7141F)))
            case .blue:
                let r = Engine.blueRadius * scale
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0x2456B8)))
            case .tri:
                let r = Engine.triRadius * scale
                var tri = Path()
                tri.move(to: CGPoint(x: c.x, y: c.y - r))
                tri.addLine(to: CGPoint(x: c.x + r * 0.9, y: c.y + r * 0.7))
                tri.addLine(to: CGPoint(x: c.x - r * 0.9, y: c.y + r * 0.7))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(e.fever ? Color(hex: 0xF2F1EE) : Color(hex: 0xEAA83A)))
            case .dot:
                let r = Engine.pegRadius * scale
                let lit = p.boardHit || p.lit > 0
                let col = lit ? Color(hex: 0xD7141F).opacity(p.boardHit ? 0.85 : 1) : pal.peg
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(col))
            }
        }

        // 飛んでいる玉
        for b in e.balls {
            let c = CGPoint(x: origin.x + b.x * scale, y: origin.y + b.y * scale)
            let r = Engine.ballRadius * scale
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(pal.ball))
        }

        // 待機玉・狙い・パワー弧（Web の drawAim / drawLaunch 相当）
        if session.canShoot {
            let L = Engine.launchPoint
            let c = CGPoint(x: origin.x + L.x * scale, y: origin.y + L.y * scale)
            let r = Engine.ballRadius * scale
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(pal.ball))

            if session.level > 0 {
                let (vx, vy) = e.launchVelocity(pullX: session.pullX, pullY: session.pullY, exact: true)
                for i in 1...10 {
                    let t = Double(i) * 0.035
                    let x = L.x + vx * t
                    let y = L.y + vy * t + Engine.gravity * t * t / 2
                    let alpha = (1 - Double(i) / 11) * 0.7
                    let p = CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
                    let rr = 1.8 * scale
                    var layer = ctx
                    layer.opacity = alpha
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)), with: .color(pal.ink))
                }

                let base = atan2(-vy, -vx)
                let spread = 0.42
                for i in 0..<Engine.levels {
                    let rad = (17.0 + Double(i) * 8) * scale
                    var arc = Path()
                    arc.addArc(center: c, radius: rad, startAngle: .radians(base - spread), endAngle: .radians(base + spread), clockwise: false)
                    let on = i < session.level
                    let col: Color = on ? (session.level == Engine.levels ? Color(hex: 0xEAA83A) : Color(hex: 0xD7141F)) : pal.peg
                    ctx.stroke(arc, with: .color(col), style: StrokeStyle(lineWidth: (on ? 3.5 : 2) * scale, lineCap: .round))
                }
            } else if session.firstShot {
                ctx.draw(
                    Text("引っ張ってはなす")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundColor(pal.ink.opacity(0.7)),
                    at: CGPoint(x: origin.x + Engine.logicalWidth / 2 * scale, y: origin.y + 188 * scale),
                    anchor: .center
                )
                ctx.draw(
                    Text("×は倍率　●は戻る玉　点線は減る玉")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundColor(pal.ink.opacity(0.55)),
                    at: CGPoint(x: origin.x + Engine.logicalWidth / 2 * scale, y: origin.y + (top - 30) * scale),
                    anchor: .center
                )
            }
        }
    }

    static func slotColors(m: Int, b: Int, fever: Bool) -> (Color, Color) {
        if b < 0 {
            return fever
                ? (Color(hex: 0xC48A2C), Color(hex: 0x1C1716).opacity(0.45))
                : (Color(hex: 0x140F0E), Color(hex: 0xF2F1EE).opacity(0.35))
        }
        if m >= 5 { return (Color(hex: 0xD7141F), Color(hex: 0xF2F1EE)) }
        if m == 3 {
            return fever
                ? (Color(hex: 0x1C1716), Color(hex: 0xEAA83A))
                : (Color(hex: 0xEAA83A), Color(hex: 0x1C1716))
        }
        if m == 1 {
            return fever
                ? (Color(hex: 0xC48A2C), Color(hex: 0x1C1716))
                : (Color(hex: 0x4A3D39), Color(hex: 0xF2F1EE))
        }
        return fever
            ? (Color(hex: 0xC48A2C), Color(hex: 0x1C1716).opacity(0.45))
            : (Color(hex: 0x1E1817), Color(hex: 0xF2F1EE).opacity(0.35))
    }
}

// MARK: - Session

@MainActor
final class PlaySession: ObservableObject {
    let engine = Engine()
    @Published var ballsLeft = 12
    @Published var score = 0
    @Published var boardShots = 0
    @Published var gauge = 0
    @Published var feverLeft = 0
    @Published var busy = false
    @Published var gameOver = false
    @Published var firstShot = true
    @Published var level = 0
    @Published var pullX = 0.0
    @Published var pullY = 0.0
    @Published var banner: BannerData?
    @Published var paletteTick = 0

    private var lastDate: Date?
    private var triBonus = false
    private var heightSet = false

    var canShoot: Bool {
        !busy && !gameOver && ballsLeft >= engine.config.cost && engine.balls.isEmpty
    }

    var feverGaugeProgress: CGFloat {
        if engine.fever { return CGFloat(feverLeft) / CGFloat(engine.config.feverShots) }
        return CGFloat(min(1, Double(gauge) / Double(engine.config.feverAt)))
    }

    var palette: PlayPalette {
        _ = paletteTick
        if engine.fever {
            return PlayPalette(
                bg: Color(hex: 0xEAA83A),
                ink: Color(hex: 0x1C1716),
                dim: Color(hex: 0x1C1716).opacity(0.45),
                peg: Color(hex: 0x1C1716).opacity(0.26),
                ball: Color(hex: 0x1C1716),
                floor: Color(hex: 0xC48A2C)
            )
        }
        return PlayPalette(
            bg: Color(hex: 0x2A2322),
            ink: Color(hex: 0xF2F1EE),
            dim: Color(hex: 0xF2F1EE).opacity(0.4),
            peg: Color(hex: 0x54463F),
            ball: Color(hex: 0xF2F1EE),
            floor: Color(hex: 0x1E1817)
        )
    }

    func ensureHeight(_ lh: Double) {
        if !heightSet {
            engine.logicalHeight = lh
            heightSet = true
        }
    }

    func resetBoard() {
        engine.applyConf(.freePlay)
        engine.boardSeed = nil
        engine.stage = 0
        engine.fever = false
        engine.balls = []
        engine.pot = 0
        engine.conveyor = 0
        engine.time = 0
        engine.setLayout(0, animate: false)
        ballsLeft = engine.config.startBalls
        score = 0
        boardShots = 0
        gauge = 0
        feverLeft = 0
        busy = false
        gameOver = false
        firstShot = true
        level = 0
        pullX = 0
        pullY = 0
        banner = nil
        triBonus = false
        paletteTick += 1
        wireHooks()
    }

    private func wireHooks() {
        engine.hooks.hit = { [weak self] _, _, _, _, _, pts in
            guard let self else { return }
            if !self.engine.fever {
                self.gauge += pts
            }
            // ▲▲▲
            if !self.triBonus {
                let tris = self.engine.pegs.filter { $0.kind == .tri }
                if tris.count == self.engine.config.tris, tris.allSatisfy(\.triHit) {
                    self.triBonus = true
                    self.ballsLeft += 3
                    self.showBanner("▲▲▲", "3つとも当てて +3玉", Color(hex: 0xEAA83A))
                }
            }
        }
        engine.hooks.shotEnd = { [weak self] pay in
            guard let self else { return }
            self.score += self.engine.shotScore
            self.ballsLeft += pay
            self.busy = false
            self.feverStep()
            self.afterShot()
            self.paletteTick += 1
            if self.ballsLeft < self.engine.config.cost {
                self.gameOver = true
            }
        }
        engine.hooks.perfect = { [weak self] bonus in
            self?.showBanner("PERFECT", "ドットをすべて赤くした +\(bonus)", Color(hex: 0xD7141F))
        }
    }

    func setPull(dx: Double, dy: Double) {
        // Web の setPull と同じ
        let mag = hypot(dx, max(0, dy))
        let maxPull = Engine.maxPull
        let levels = Engine.levels
        level = mag < 14 ? 0 : min(levels, Int(ceil(mag / (maxPull / Double(levels)))))
        let len = hypot(dx, dy)
        if len < 0.0001 {
            pullX = 0; pullY = 0
            return
        }
        let p = Double(level) / Double(levels) * maxPull
        pullX = dx / len * p
        pullY = dy / len * p
    }

    func releasePull() {
        defer {
            pullX = 0; pullY = 0; level = 0
        }
        guard canShoot, level > 0 else { return }
        let (vx, vy) = engine.launchVelocity(pullX: pullX, pullY: pullY, exact: false)
        engine.launch(vx: vx, vy: vy)
        ballsLeft -= engine.config.cost
        busy = true
        firstShot = false
        triBonus = false
        lastDate = nil
        wireHooks()
    }

    private func feverStep() {
        if engine.fever {
            feverLeft -= 1
            if feverLeft <= 0 {
                engine.fever = false
                gauge = 0
            }
        } else if gauge >= engine.config.feverAt {
            engine.fever = true
            feverLeft = engine.config.feverShots
            showBanner("FEVER", "\(engine.config.feverShots)回、ポイント2倍・玉が減らない", Color(hex: 0xD7141F))
        }
    }

    private func afterShot() {
        boardShots += 1
        if boardShots >= engine.config.shotsPerBoard {
            boardShots = 0
            var next: Int
            repeat { next = Int.random(in: 0..<Engine.layouts) } while next == engine.layout
            engine.setLayout(next, animate: true)
            engine.stage += 1
            showBanner("STAGE \(engine.stage + 1)", "ステージが上がりました", Color(hex: 0xF2F1EE))
        } else {
            engine.pickGold()
        }
    }

    func showBanner(_ word: String, _ sub: String, _ color: Color) {
        banner = BannerData(word: word, sub: sub, color: color, born: Date())
    }

    func tick(now: Date) {
        // 帯の寿命
        if let b = banner, now.timeIntervalSince(b.born) > 1.5 {
            banner = nil
        }
        // 釘の lit 減衰・レイアウト補間（Web と同じ係数）
        let real: Double
        if let last = lastDate {
            real = min(now.timeIntervalSince(last), 1.0 / 30.0)
        } else {
            real = 0
        }
        lastDate = now

        if real > 0 {
            for p in engine.pegs {
                p.pulse = max(0, p.pulse - real * 5)
                if engine.balls.isEmpty {
                    p.lit = max(0, p.lit - real * 1.2)
                }
                if p.m < 1 {
                    p.m = min(1, p.m + real * 1.4)
                    let k = 1 - pow(1 - p.m, 3)
                    p.x = p.fx + (p.tx - p.fx) * k
                    p.y = p.fy + (p.ty - p.fy) * k
                }
            }
            if engine.balls.isEmpty && !busy {
                engine.time += real
                engine.conveyor += Engine.conveyorSpeed * real
            }
        }

        guard busy else { return }
        var left = real
        let step = Engine.physicsSubstep
        while left > 0 {
            let d = min(step, left)
            engine.stepPhysics(dt: d)
            left -= d
            if !busy { break }
        }
    }
}
