import SwiftUI
import DotDropEngine

/// フェーズ1：物理エンジンをつないだ簡易プレイ。演出・音・HUD はまだ最小。
struct PlayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = PlaySession()

    private let bg = Color(red: 0x2A / 255, green: 0x23 / 255, blue: 0x22 / 255)
    private let ink = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xEE / 255)
    private let red = Color(red: 0xD7 / 255, green: 0x14 / 255, blue: 0x1F / 255)
    private let yellow = Color(red: 0xEA / 255, green: 0xA8 / 255, blue: 0x3A / 255)
    private let blue = Color(red: 0x24 / 255, green: 0x56 / 255, blue: 0xB8 / 255)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Engine.logicalWidth, geo.size.height / session.engine.logicalHeight)
            let boardW = Engine.logicalWidth * scale
            let boardH = session.engine.logicalHeight * scale
            let origin = CGPoint(
                x: (geo.size.width - boardW) / 2,
                y: (geo.size.height - boardH) / 2
            )

            ZStack(alignment: .topLeading) {
                bg.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { ctx, _ in
                        session.tick(now: timeline.date)
                        let e = session.engine

                        // 受け皿の線
                        let slotY = e.slotTop() * scale + origin.y
                        var slotPath = Path()
                        slotPath.move(to: CGPoint(x: origin.x, y: slotY))
                        slotPath.addLine(to: CGPoint(x: origin.x + boardW, y: slotY))
                        ctx.stroke(slotPath, with: .color(ink.opacity(0.25)), lineWidth: 2)

                        for p in e.pegs {
                            let c = CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
                            switch p.kind {
                            case .square:
                                let s = Engine.squareHalf * 2 * scale
                                let r = CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
                                ctx.fill(Path(r), with: .color(p.boardHit || p.lit > 0 ? red : ink.opacity(0.35)))
                            case .blue:
                                let r = Engine.blueRadius * scale
                                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(blue))
                            case .tri:
                                let r = Engine.triRadius * scale
                                var tri = Path()
                                tri.move(to: CGPoint(x: c.x, y: c.y - r))
                                tri.addLine(to: CGPoint(x: c.x + r * 0.9, y: c.y + r * 0.7))
                                tri.addLine(to: CGPoint(x: c.x - r * 0.9, y: c.y + r * 0.7))
                                tri.closeSubpath()
                                ctx.fill(tri, with: .color(yellow))
                            case .dot:
                                let r = Engine.pegRadius * scale
                                let color = (p.boardHit || p.lit > 0) ? red.opacity(0.85) : ink.opacity(0.45)
                                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
                            }
                        }

                        for b in e.balls {
                            let c = CGPoint(x: origin.x + b.x * scale, y: origin.y + b.y * scale)
                            let r = Engine.ballRadius * scale
                            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ink))
                        }

                        // 待機玉
                        if !session.busy {
                            let L = Engine.launchPoint
                            let c = CGPoint(x: origin.x + L.x * scale, y: origin.y + L.y * scale)
                            let r = Engine.ballRadius * scale
                            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ink))

                            if let pull = session.pull {
                                var aim = Path()
                                aim.move(to: c)
                                aim.addLine(to: CGPoint(x: origin.x + pull.x * scale, y: origin.y + pull.y * scale))
                                ctx.stroke(aim, with: .color(ink.opacity(0.35)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            }
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !session.busy else { return }
                                let lx = (value.location.x - origin.x) / scale
                                let ly = (value.location.y - origin.y) / scale
                                session.updatePull(logical: CGPoint(x: lx, y: ly))
                            }
                            .onEnded { _ in
                                session.releasePull()
                            }
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("とじる") { dismiss() }
                            .foregroundStyle(ink)
                        Spacer()
                        Text("持ち玉 \(session.ballsLeft)")
                            .foregroundStyle(ink)
                        Text("スコア \(session.score)")
                            .foregroundStyle(ink)
                    }
                    .font(.system(size: 15, weight: .bold))
                    Text(session.status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ink.opacity(0.55))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .onAppear { session.resetBoard() }
    }
}

@MainActor
final class PlaySession: ObservableObject {
    let engine = Engine()
    @Published var ballsLeft = 12
    @Published var score = 0
    @Published var status = "画面を引っ張ってはなす"
    @Published var busy = false
    @Published var pull: CGPoint?

    private var lastDate: Date?
    private var awaitingEnd = false

    func resetBoard() {
        engine.applyConf(.freePlay)
        engine.boardSeed = nil
        engine.stage = 0
        engine.fever = false
        engine.logicalHeight = 700
        engine.setLayout(0, animate: false)
        ballsLeft = engine.config.startBalls
        score = 0
        busy = false
        pull = nil
        status = "画面を引っ張ってはなす"
    }

    func updatePull(logical: CGPoint) {
        let L = Engine.launchPoint
        // 引いた方向（発射は反対）
        var dx = logical.x - L.x
        var dy = logical.y - L.y
        // 打てるのは水平より上＝引きは下方向が主。Web と同じく pull ベクトルを保持
        let len = hypot(dx, dy)
        let maxP = Engine.maxPull
        if len > maxP {
            dx = dx / len * maxP
            dy = dy / len * maxP
        }
        pull = CGPoint(x: L.x + dx, y: L.y + dy)
    }

    func releasePull() {
        guard !busy, let pull, ballsLeft > 0 else {
            self.pull = nil
            return
        }
        let L = Engine.launchPoint
        let pullX = pull.x - L.x
        let pullY = pull.y - L.y
        // 水平より上だけ（上向きに引いても水平）— launchVelocity 内で max(0, pullY)
        // Web: 引いた方向の反対へ飛ぶ。下に引くと上へ。
        if pullY <= 0 {
            // 上方向への引きは無効に近い。Web は max(0,pullY) で縦成分0に
            status = "下に引っ張ってはなす"
            self.pull = nil
            return
        }
        let (vx, vy) = engine.launchVelocity(pullX: pullX, pullY: pullY, exact: false)
        engine.launch(vx: vx, vy: vy)
        ballsLeft -= engine.config.cost
        busy = true
        awaitingEnd = true
        self.pull = nil
        status = "…"
        lastDate = nil

        engine.hooks.shotEnd = { [weak self] pay in
            guard let self else { return }
            self.score += self.engine.shotScore
            self.ballsLeft += pay
            self.busy = false
            self.awaitingEnd = false
            self.status = pay >= 0 ? "+\(pay) 玉 · +\(self.engine.shotScore) 点" : "\(pay) 玉 · +\(self.engine.shotScore) 点"
            if self.ballsLeft <= 0 {
                self.status = "玉切れ · スコア \(self.score)"
            }
        }
    }

    func tick(now: Date) {
        guard busy else {
            lastDate = now
            return
        }
        let last = lastDate ?? now
        lastDate = now
        var dt = now.timeIntervalSince(last)
        // 1フレーム分を亜刻みで（Web と同じ 1/360）
        dt = min(dt, 1.0 / 30.0)
        let step = Engine.physicsSubstep
        var left = dt
        while left > 0 {
            let d = min(step, left)
            engine.stepPhysics(dt: d)
            left -= d
            if !busy { break }
        }
    }
}
