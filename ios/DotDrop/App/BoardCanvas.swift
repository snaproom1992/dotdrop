import SwiftUI
import DotDropEngine

/// `draw()` の釘・受け皿・玉・狙い。座標は Web と同じ（原点は画面上、ox で横センタ）
/// 描画順も Web に合わせる：光の柱 → 背景数字 → 発射前 → 帯 → 釘 → 受け皿 → 玉 → 吹き出し → 吸い込み
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
        // 揺れ
        let shakeAmt = session.shake
        let sxOff = shakeAmt > 0 ? (Double.random(in: 0...1) - 0.5) * 14 * shakeAmt * Double(s) : 0
        let syOff = shakeAmt > 0 ? (Double.random(in: 0...1) - 0.5) * 14 * shakeAmt * Double(s) : 0
        let top = e.slotTop()
        let screenH = fit.screenH
        let slotW = Engine.slotWidth
        let convLen = e.conveyorLength
        let f = e.field()
        let cy = (f.top + f.bottom) / 2

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DD.bg(fever: fever)))

        // 節目で背景が一瞬色づく
        if let m = session.milestoneFx, m.t < 0.35 {
            var flash = ctx
            flash.opacity = (1 - m.t / 0.35) * 0.55
            flash.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(GameFx.resolveColor(m.color, t: m.t))
            )
        }

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + x * s + sxOff, y: y * s + syOff)
        }

        func slotLogicalX(_ i: Int) -> Double {
            var u = (Double(i) * slotW + e.conveyor).truncatingRemainder(dividingBy: convLen)
            if u < 0 { u += convLen }
            var x = u
            if x > Engine.logicalWidth + slotW { x -= convLen }
            return x
        }

        let ease = GameFx.ease

        // ---- 光の柱（入った受け皿）上へ消えるグラデ ----
        for c in session.catches where c.m != 0 {
            let x = slotLogicalX(c.slot)
            let col = GameFx.multColor(c.m, fever: fever)
            let alpha = (1 - ease(c.t)) * (session.shotBallsMax > 3 ? 0.25 : 0.5)
            let origin = pt(x + 2, top - 420)
            let w = (slotW - 4) * s
            let h = 420 * s
            let rect = CGRect(x: origin.x, y: origin.y, width: w, height: h)
            var layer = ctx
            layer.opacity = alpha
            let grad = Gradient(stops: [
                .init(color: col, location: 0),
                .init(color: col.opacity(0), location: 1)
            ])
            layer.fill(
                Path(rect),
                with: .linearGradient(
                    grad,
                    startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                    endPoint: CGPoint(x: rect.midX, y: rect.minY)
                )
            )
        }

        // ---- 今回のポイント（背景の大きな数字）----
        let bgNumAlpha = session.potAlpha * (1 - GameFx.milestoneVisible(session.milestoneFx))
        if bgNumAlpha > 0.01, e.pot > 0 {
            let landed = e.shotScore > 0
            let pulse = 1 + session.potPulse * 0.08
            let base: Double = e.pot >= 100 ? 150 : 210
            let fontSize = base * (landed ? 0.5 : pulse) * s
            var layer = ctx
            layer.opacity = bgNumAlpha
            layer.draw(
                Text("\(Int(session.potShow.rounded()))")
                    .font(DD.bold(fontSize))
                    .foregroundColor(DD.big(fever: fever)),
                at: pt(Engine.logicalWidth / 2, landed ? cy - 100 : cy),
                anchor: .center
            )
            if landed {
                let ss = session.shotShow
                let shotSize = (ss >= 1000 ? 110.0 : 150.0) * s
                var shotLayer = ctx
                shotLayer.opacity = bgNumAlpha * 0.9
                shotLayer.draw(
                    Text("+\(Int(ss.rounded()))")
                        .font(DD.bold(shotSize))
                        .foregroundColor(fever ? DD.ink : DD.paper),
                    at: pt(Engine.logicalWidth / 2, cy + 20),
                    anchor: .center
                )
            }
        }

        // ---- 発射前の飾りと、待っている玉（帯より奥）----
        drawLaunch(ctx: ctx, e: e, fever: fever, s: s, top: top, pt: pt)
        if session.canShoot, session.level == 0 {
            drawLaunchBall(ctx: ctx, e: e, fever: fever, s: s, pt: pt)
        }

        // ---- 帯 ----
        drawBanner(ctx: ctx, size: size, s: s, ox: ox)

        // ---- 釘（波紋 bump + PERFECT 光）----
        for p in e.pegs {
            var bumpR = 0.0
            for w in session.waves {
                let d = hypot(p.x - w.x, p.y - w.y)
                let front = w.t * 260
                let k = 1 - abs(d - front) / 26
                if k > 0, d < 150 {
                    bumpR += k * (1 - d / 150) * (w.big ? 4 : 2.2)
                }
            }
            let pg = GameFx.perfectGlow(y: p.y, fx: session.perfectFx)
            let grow = p.pulse * 5 + min(bumpR, 6) + pg * 4.5
            let c = pt(p.x, p.y)
            switch p.kind {
            case .square:
                let h = (Engine.squareHalf + grow) * s
                ctx.fill(Path(CGRect(x: c.x - h, y: c.y - h, width: h * 2, height: h * 2)), with: .color(DD.red))
            case .blue:
                let holding = e.balls.contains { $0.state == .held && $0.hold === p }
                let r = (Engine.blueRadius + grow + (holding ? 5 : 0)) * s
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
                if pg > 0.02 {
                    col = DD.red; op = 1
                } else if p.lit > 0.02 {
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

        // ---- 受け皿 ----
        for i in 0..<e.config.slotM.count {
            let x = slotLogicalX(i)
            if x < -slotW || x > Engine.logicalWidth { continue }
            let info = e.slotInfo(i)
            let (fill, fg) = slotColors(m: info.m, b: info.b, fever: fever)
            let catchBeam = session.catches.last(where: { $0.slot == i })
            let k = catchBeam.map { 1 - ease($0.t / 0.5) } ?? 0
            let lift = (catchBeam != nil && catchBeam!.m > 0) ? 8 * k : 0

            let origin = pt(x + 2, top + 6 - lift)
            let w = (slotW - 4) * s
            let h = max((screenH + 14 - top - 6 + lift) * s, 40)
            let rect = CGRect(x: origin.x, y: origin.y, width: w, height: h)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 6 * s), with: .color(fill))
            if catchBeam != nil, catchBeam!.m > 0, k > 0.05 {
                ctx.stroke(
                    Path(roundedRect: rect, cornerRadius: 6 * s),
                    with: .color(DD.ball(fever: fever)),
                    lineWidth: 2.5 * k * s
                )
            }
            if let sf = session.slotFlash, sf.t < 2, sf.slots.contains(i), sin(sf.t * 18) > 0 {
                let flashOrigin = pt(x + 2, top + 6)
                let flashRect = CGRect(
                    x: flashOrigin.x, y: flashOrigin.y,
                    width: (slotW - 4) * s,
                    height: max((screenH + 14 - top - 6) * s, 40)
                )
                ctx.stroke(Path(roundedRect: flashRect, cornerRadius: 6 * s), with: .color(DD.red), lineWidth: 3 * s)
            }

            let cx = ox + (x + slotW / 2) * s
            let fontSize = ((info.m >= 5 ? 26.0 : 22.0) + k * 8) * s
            ctx.draw(
                Text("×\(info.m)").font(DD.bold(fontSize)).foregroundColor(fg),
                at: CGPoint(x: cx, y: (top + 28 - lift) * s),
                anchor: .center
            )
            if info.b > 0 {
                for j in 0..<info.b {
                    let oxj = (Double(j) - Double(info.b - 1) / 2) * 11
                    let c = CGPoint(x: cx + oxj * s, y: (top + 50 - lift) * s)
                    let r = 3.5 * s
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(fg))
                }
            } else if info.b < 0 {
                let n = -info.b
                let stroke = fever ? DD.ink : DD.red
                for j in 0..<n {
                    let oxj = (Double(j) - Double(n - 1) / 2) * 14
                    let c = CGPoint(x: cx + oxj * s, y: (top + 50 - lift) * s)
                    let r = 5 * s
                    let path = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    ctx.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: 1.6 * s, dash: [2.2 * s, 2 * s]))
                }
            }
        }

        // ---- 数字ドン ----
        drawMilestone(ctx: ctx, s: s, cy: cy, pt: pt)

        // ---- 玉（引いている間は狙いも手前）----
        if session.canShoot, session.level > 0 {
            drawAim(ctx: ctx, e: e, fever: fever, s: s, pt: pt)
            drawLaunchBall(ctx: ctx, e: e, fever: fever, s: s, pt: pt)
        }

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
            let BR = Engine.ballRadius
            let trail = b.trail
            for (i, tp) in trail.enumerated() {
                let c = pt(tp.0, tp.1)
                let frac = Double(i + 1) / Double(max(1, trail.count))
                let r = BR * frac * s
                var layer = ctx
                layer.opacity = frac * 0.25
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ball))
            }
            let c = pt(b.x, b.y)
            var glow = ctx
            glow.opacity = 0.2
            let gr = (BR + 6) * s
            glow.fill(Path(ellipseIn: CGRect(x: c.x - gr, y: c.y - gr, width: gr * 2, height: gr * 2)), with: .color(ball))
            let r = BR * s
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ball))
        }

        // ---- 吹き出し ----
        for fl in session.floaters {
            let life = fl.life
            let alpha = max(0, 1 - fl.t / life)
            let p = pt(fl.x, fl.y - fl.t * 34)
            var layer = ctx
            layer.opacity = alpha
            layer.draw(
                Text(fl.text)
                    .font(DD.bold((fl.big ? 24 : 18) * s))
                    .foregroundColor(fl.color),
                at: p,
                anchor: .center
            )
        }

        // ---- 吸い込み ----
        let tgtBall = session.moneyTargetScreen()
        let tgtScore = session.scoreTargetScreen()
        for fy in session.flyers {
            if fy.t < 0 { continue }
            let tgt: CGPoint
            switch fy.kind {
            case .ball: tgt = tgtBall
            case .minus: tgt = pt(fy.tx, fy.ty)
            case .score: tgt = tgtScore
            }
            let k = pow(min(1, fy.t / 0.55), 2.2)
            let x0 = ox + fy.x0 * s
            let y0 = fy.y0 * s
            let x = x0 + (tgt.x - x0) * k + sin(k * .pi) * fy.arc * s
            let y = y0 + (tgt.y - y0) * k - sin(k * .pi) * 60 * s
            switch fy.kind {
            case .ball:
                let r = Engine.ballRadius * (1 - k * 0.35) * s
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(fy.color))
            case .minus:
                let r = Engine.ballRadius * s
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(fy.color),
                    style: StrokeStyle(lineWidth: 2 * s, dash: [3 * s, 2.5 * s])
                )
            case .score:
                ctx.draw(
                    Text("+\(fy.value)")
                        .font(DD.bold((24 - k * 10) * s))
                        .foregroundColor(fy.color),
                    at: CGPoint(x: x, y: y),
                    anchor: .center
                )
            }
        }

        // ---- ふちの光 ----
        if let edge = session.edge, edge.t < 0.9 {
            var layer = ctx
            layer.opacity = 1 - edge.t / 0.9
            let lw = max(8, edge.width) * s
            layer.stroke(
                Path(CGRect(x: lw / 2, y: lw / 2, width: size.width - lw, height: size.height - lw)),
                with: .color(GameFx.resolveColor(edge.color, t: edge.t)),
                lineWidth: lw
            )
        }
    }

    private func drawMilestone(
        ctx: GraphicsContext, s: CGFloat, cy: Double,
        pt: (Double, Double) -> CGPoint
    ) {
        guard let m = session.milestoneFx, m.t <= 1.1 else { return }
        let ease = GameFx.ease
        let inK = min(1, m.t / 0.12)
        let sc: Double
        if m.t < 0.12 {
            sc = 2.4 - 1.4 * ease(inK)
        } else if m.t < 0.22 {
            sc = 1 + 0.08 * sin((m.t - 0.12) / 0.1 * .pi)
        } else {
            sc = 1
        }
        let alpha = m.t > 0.8 ? 1 - (m.t - 0.8) / 0.3 : 1
        let col = GameFx.resolveColor(m.color, t: m.t)
        let sizePt = (m.level >= 10 ? 130.0 : 150.0) * s
        let center = pt(Engine.logicalWidth / 2, cy - 10)
        var layer = ctx
        layer.opacity = max(0, alpha)
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: sc, y: sc)
        layer.draw(
            Text("\(m.level * 100)")
                .font(DD.bold(sizePt))
                .foregroundColor(Color(hex: 0x1C1716, opacity: 0.55)),
            at: CGPoint(x: 4 * s, y: 6 * s),
            anchor: .center
        )
        layer.draw(
            Text("\(m.level * 100)")
                .font(DD.bold(sizePt))
                .foregroundColor(col),
            at: .zero,
            anchor: .center
        )
        layer.draw(
            Text("POINTS")
                .font(DD.bold(14 * s))
                .foregroundColor(col),
            at: CGPoint(x: 0, y: sizePt * 0.55),
            anchor: .center
        )
    }

    private func drawLaunchBall(
        ctx: GraphicsContext, e: Engine, fever: Bool, s: CGFloat,
        pt: (Double, Double) -> CGPoint
    ) {
        guard session.canShoot else { return }
        let L = e.launchPoint
        let c = pt(L.x, L.y)
        let r = (Engine.ballRadius + Double(session.level) / Double(Engine.levels) * 1.2) * s
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
            with: .color(DD.ball(fever: fever))
        )
    }

    private func drawLaunch(
        ctx: GraphicsContext, e: Engine, fever: Bool, s: CGFloat, top: Double,
        pt: (Double, Double) -> CGPoint
    ) {
        guard session.canShoot else { return }
        let L = e.launchPoint
        let c = pt(L.x, L.y)
        let bannerUp = session.bannerUp

        if session.level == 0 && !bannerUp {
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

        if session.level == 0 && session.firstShot && !bannerUp {
            ctx.draw(
                Text("引っ張ってはなす")
                    .font(DD.regular(13 * s))
                    .foregroundColor(DD.fg(fever: fever).opacity(0.7)),
                at: pt(Engine.logicalWidth / 2, L.y + 48),
                anchor: .center
            )
            ctx.draw(
                Text("×は倍率　●は戻る玉　点線は減る玉")
                    .font(DD.regular(13 * s))
                    .foregroundColor(DD.fg(fever: fever).opacity(0.7)),
                at: pt(Engine.logicalWidth / 2, top - 30),
                anchor: .center
            )
        }
    }

    private func drawAim(
        ctx: GraphicsContext, e: Engine, fever: Bool, s: CGFloat,
        pt: (Double, Double) -> CGPoint
    ) {
        let L = e.launchPoint
        let c = pt(L.x, L.y)
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
    }

    /// 帯。［大きな見出し］［細い区切り線］［説明］を左から順に詰める。
    ///
    /// **文字の幅は必ず測ること。**「文字数 × 0.62」のような見積もりで置いてはいけない。
    /// 日本語は1文字がほぼ倍の幅なので説明文の幅が大きく外れ、右で切れるうえ、
    /// 同じ見積もりで決めている区切り線が見出しにかぶったり離れたりする。
    private func drawBanner(ctx: GraphicsContext, size: CGSize, s: CGFloat, ox _: CGFloat) {
        guard let b = session.banner, b.t <= 1.5 else { return }
        let ease = GameFx.ease
        let t = b.t

        // 帯は画面のはしからはしまで。左から入って右へ抜ける
        let LW = Double(size.width)
        let off: Double
        if t < 0.25 {
            off = -LW * (1 - ease(t / 0.25))
        } else if t > 1.2 {
            off = LW * ease((t - 1.2) / 0.3)
        } else {
            off = 0
        }
        let y = Double(fit.bannerY * s)
        let h = 56 * Double(s)
        let mid = y + h / 2
        ctx.fill(Path(CGRect(x: off, y: y, width: LW, height: h)), with: .color(b.color))
        let ink: Color = (b.color == DD.paper || b.color == DD.mustard || b.color == DD.red) ? DD.ink : DD.paper

        func width(_ text: String, _ px: Double) -> Double {
            guard !text.isEmpty else { return 0 }
            return ctx.resolve(Text(text).font(DD.bold(px * Double(s))))
                .measure(in: CGSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
        }
        // 収まる大きさを探す。まず見出し、それでも足りなければ説明も縮める。
        // 62 は左の余白16＋区切りの前後14×2＋右の余白
        var wordSize = 40.0, subSize = 14.0
        func total() -> Double { width(b.word, wordSize) + width(b.sub, subSize) + 62 * Double(s) }
        while wordSize > 20, total() > LW { wordSize -= 2 }
        while subSize > 11, total() > LW { subSize -= 1 }

        let wordW = width(b.word, wordSize)
        ctx.draw(
            Text(b.word).font(DD.bold(wordSize * Double(s))).foregroundColor(ink),
            at: CGPoint(x: off + 16 * Double(s), y: mid + 2 * Double(s)),
            anchor: .leading
        )
        guard !b.sub.isEmpty else { return }
        // 見出しと説明の間に細い区切りを1本。役割が違うことが形で分かる
        let sepX = off + 16 * Double(s) + wordW + 14 * Double(s)
        var sep = ctx
        sep.opacity = 0.28
        sep.fill(
            Path(CGRect(x: sepX, y: y + 14 * Double(s), width: 1.5 * Double(s), height: h - 28 * Double(s))),
            with: .color(ink)
        )
        ctx.draw(
            Text(b.sub).font(DD.bold(subSize * Double(s))).foregroundColor(ink),
            at: CGPoint(x: sepX + 14 * Double(s), y: mid + Double(s)),
            anchor: .leading
        )
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
