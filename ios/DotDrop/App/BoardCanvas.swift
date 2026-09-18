import SwiftUI
import DotDropEngine

/// `draw()` の釘・受け皿・玉・狙い。座標は Web と同じ（原点は画面上、ox で横センタ）
struct BoardCanvas: View {
    var session: GameSession
    var fit: BoardFit

    var body: some View {
        // timeline.date を Canvas 内で読まないと再描画が止まる（@Published tick をやめたあとの罠）
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let _ = timeline.date
                draw(ctx: ctx, size: size)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard session.canShoot else { return }
                    let dx = Double(value.translation.width / fit.scale)
                    let dy = Double(value.translation.height / fit.scale)
                    session.setPull(dx: dx, dy: dy)
                }
                .onEnded { _ in session.releasePull() }
        )
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let e = session.engine
        let fever = e.fever
        let s = fit.scale
        let ox = fit.ox
        let top = e.slotTop()
        let screenH = fit.screenH

        // 背景（全面）
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DD.bg(fever: fever)))

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + x * s, y: y * s)
        }

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
            let (fill, fg) = slotColors(m: info.m, b: info.b, fever: fever)
            let origin = pt(x + 2, top + 6)
            let w = (slotW - 4) * s
            let h = max((screenH + 14 - top - 6) * s, 40)
            let rect = CGRect(x: origin.x, y: origin.y, width: w, height: h)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 6 * s), with: .color(fill))

            let cx = ox + (x + slotW / 2) * s
            let fontSize = (info.m >= 5 ? 26.0 : 22.0) * s
            ctx.draw(
                Text("×\(info.m)").font(.system(size: fontSize, weight: .bold)).foregroundColor(fg),
                at: CGPoint(x: cx, y: (top + 28) * s),
                anchor: .center
            )
            if info.b > 0 {
                for j in 0..<info.b {
                    let oxj = (Double(j) - Double(info.b - 1) / 2) * 11
                    let c = CGPoint(x: cx + oxj * s, y: (top + 50) * s)
                    let r = 3.5 * s
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(fg))
                }
            } else if info.b < 0 {
                let n = -info.b
                let stroke = fever ? DD.ink : DD.red
                for j in 0..<n {
                    let oxj = (Double(j) - Double(n - 1) / 2) * 14
                    let c = CGPoint(x: cx + oxj * s, y: (top + 50) * s)
                    let r = 5 * s
                    let path = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    ctx.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: 1.6 * s, dash: [2.2 * s, 2 * s]))
                }
            }
        }

        // 釘（draw 内の順序・色）
        for p in e.pegs {
            let c = pt(p.x, p.y)
            let grow = p.pulse * 5
            switch p.kind {
            case .square:
                let h = (Engine.squareHalf + grow) * s
                ctx.fill(Path(CGRect(x: c.x - h, y: c.y - h, width: h * 2, height: h * 2)), with: .color(DD.red))
            case .blue:
                let r = (Engine.blueRadius + grow) * s
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(DD.blue))
            case .tri:
                let t = (Engine.triRadius + 2 + grow + sin(e.time * 6)) * s
                var tri = Path()
                tri.move(to: CGPoint(x: c.x, y: c.y - t))
                tri.addLine(to: CGPoint(x: c.x + t * 0.92, y: c.y + t * 0.6))
                tri.addLine(to: CGPoint(x: c.x - t * 0.92, y: c.y + t * 0.6))
                tri.closeSubpath()
                var layer = ctx
                layer.opacity = p.triHit ? 0.55 : 1
                layer.fill(tri, with: .color(fever ? DD.paper : DD.mustard))
            case .dot:
                let r = (Engine.pegRadius + grow + p.lit * 1.5) * s
                let col: Color
                let op: Double
                if p.lit > 0.02 {
                    col = DD.red; op = 0.3 + p.lit * 0.7
                } else if p.boardHit {
                    col = DD.red; op = 0.4
                } else {
                    col = DD.peg(fever: fever); op = 1
                }
                var layer = ctx
                layer.opacity = op
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(col))
            }
        }

        // 玉
        let ball = DD.ball(fever: fever)
        for b in e.balls {
            if b.state == .held {
                let c = pt(b.x, b.y)
                let k = b.holdT / 0.5
                var ring = ctx
                ring.opacity = max(0, 1 - k)
                let rr = (Engine.blueRadius + 6 + k * 18) * s
                ring.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(DD.blue), lineWidth: 2 * s)
                let br = Engine.ballRadius * (0.55 + 0.45 * abs(cos(k * .pi))) * s
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - br, y: c.y - br, width: br * 2, height: br * 2)), with: .color(ball))
                continue
            }
            guard b.state == .fly else { continue }
            let c = pt(b.x, b.y)
            let r = Engine.ballRadius * s
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ball))
        }

        // 発射前（drawLaunch / drawLaunchBall）
        if session.canShoot {
            let L = e.launchPoint
            let c = pt(L.x, L.y)
            let bannerUp = session.banner != nil
            let r = (Engine.ballRadius + Double(session.level) / Double(Engine.levels) * 1.2) * s

            if session.level == 0 && !bannerUp {
                // 脈打つ細い円
                let pulse = (Engine.ballRadius + 8 + sin(e.time * 3) * 1.5) * s
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: c.x - pulse, y: c.y - pulse, width: pulse * 2, height: pulse * 2)),
                    with: .color(DD.fg(fever: fever).opacity(0.4)),
                    lineWidth: 1.5 * s
                )
                var arc = Path()
                arc.addArc(center: c, radius: 34 * s, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
                ctx.stroke(arc, with: .color(DD.fg(fever: fever).opacity(0.35)), style: StrokeStyle(lineWidth: 1.5 * s, dash: [2 * s, 5 * s]))
            }

            if session.level > 0 {
                let (vx, vy) = e.launchVelocity(pullX: session.pullX, pullY: session.pullY, exact: true)
                for i in 1...10 {
                    let t = Double(i) * 0.035
                    let x = L.x + vx * t
                    let y = L.y + vy * t + Engine.gravity * t * t / 2
                    let p = pt(x, y)
                    let rr = 1.8 * s
                    var layer = ctx
                    layer.opacity = (1 - Double(i) / 11) * 0.7
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)), with: .color(DD.fg(fever: fever)))
                }
                let base = atan2(-vy, -vx)
                let spread = 0.42
                for i in 0..<Engine.levels {
                    let rad = (17.0 + Double(i) * 8) * s
                    var arc = Path()
                    arc.addArc(center: c, radius: rad, startAngle: .radians(base - spread), endAngle: .radians(base + spread), clockwise: false)
                    let on = i < session.level
                    let col: Color = on ? (session.level == Engine.levels ? DD.mustard : DD.red) : DD.peg(fever: fever)
                    ctx.stroke(arc, with: .color(col), style: StrokeStyle(lineWidth: (on ? 3.5 : 2) * s, lineCap: .round))
                }
            } else if session.firstShot && !bannerUp {
                ctx.draw(
                    Text("引っ張ってはなす")
                        .font(.system(size: 13 * s, weight: .medium))
                        .foregroundColor(DD.fg(fever: fever).opacity(0.7)),
                    at: pt(Engine.logicalWidth / 2, L.y + 48),
                    anchor: .center
                )
                ctx.draw(
                    Text("×は倍率　●は戻る玉　点線は減る玉")
                        .font(.system(size: 13 * s, weight: .medium))
                        .foregroundColor(DD.fg(fever: fever).opacity(0.7)),
                    at: pt(Engine.logicalWidth / 2, top - 30),
                    anchor: .center
                )
            }

            // 玉は帯より手前（常に描く）
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ball))
        }

        // 帯
        if let b = session.banner {
            let y = fit.bannerY * s
            let h = 56 * s
            let rect = CGRect(x: 0, y: y, width: size.width, height: h)
            ctx.fill(Path(rect), with: .color(b.color))
            let ink: Color = (b.color == DD.paper || b.color == DD.mustard || b.color == DD.red) ? DD.ink : DD.paper
            ctx.draw(
                Text(b.word).font(.system(size: 32 * s, weight: .bold)).foregroundColor(ink),
                at: CGPoint(x: 16 * s + ox, y: y + h / 2),
                anchor: .leading
            )
            // 区切り＋説明は簡略だが位置は帯内
            ctx.draw(
                Text(b.sub).font(.system(size: 13 * s, weight: .bold)).foregroundColor(ink),
                at: CGPoint(x: size.width * 0.42, y: y + h / 2),
                anchor: .leading
            )
        }
    }

    private func slotColors(m: Int, b: Int, fever: Bool) -> (Color, Color) {
        if b < 0 {
            return fever
                ? (Color(hex: 0xC48A2C), DD.ink.opacity(0.45))
                : (Color(hex: 0x140F0E), DD.paper.opacity(0.35))
        }
        if m >= 5 { return (DD.red, DD.paper) }
        if m == 3 {
            return fever ? (DD.ink, DD.mustard) : (DD.mustard, DD.ink)
        }
        if m == 1 {
            return fever
                ? (Color(hex: 0xC48A2C), DD.ink)
                : (Color(hex: 0x4A3D39), DD.paper)
        }
        return fever
            ? (Color(hex: 0xC48A2C), DD.ink.opacity(0.45))
            : (DD.floorNormal, DD.paper.opacity(0.35))
    }
}
