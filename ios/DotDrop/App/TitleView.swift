import SwiftUI

/// `#start` overlay（justify-content: safe center）
struct TitleView: View {
    var session: GameSession
    var onPlay: () -> Void
    var onTutorial: () -> Void

    var body: some View {
        ZStack {
            DD.brown
            VStack(spacing: 0) {
                titleBlock
                shapes
                    .padding(.top, 22)
                startButton
                    .padding(.top, 28)
                tutorialButton
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleBlock: some View {
        // h1: 76px / letter-spacing -.06em / line-height .9
        // O は .38em・左右 .17em。alignmentGuide は使わない（AttributeGraph cycle の原因になる）
        // HStack 中央揃え ≈ CSS の baseline + top:-.17em の見え方
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text("D")
                DropO()
                Text("T")
            }
            Text("DROP")
        }
        .font(DD.bold(76))
        .foregroundStyle(DD.paper)
        .tracking(-76 * 0.06)
        .lineSpacing(-76 * 0.1)
        .multilineTextAlignment(.center)
    }

    private var shapes: some View {
        HStack(spacing: 14) {
            Rectangle().fill(DD.red).frame(width: 22, height: 22)
            Circle().fill(DD.blue).frame(width: 22, height: 22)
            Triangle().fill(DD.mustard).frame(width: 26, height: 22)
        }
    }

    private var startButton: some View {
        Button(action: onPlay) {
            Text("はじめる")
                .font(DD.bold(18))
                .foregroundStyle(DD.paper)
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(DD.red)
                .clipShape(Capsule())
        }
    }

    private var tutorialButton: some View {
        Button(action: onTutorial) {
            VStack(spacing: 9) {
                Text("あそびかた")
                    .font(DD.bold(16))
                HStack(spacing: 5) {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(i < session.tutorialCleared.count ? DD.red : DD.paper.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .foregroundStyle(DD.paper)
            .padding(.vertical, 15)
            .padding(.horizontal, 30)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(DD.paper, lineWidth: 2))
        }
    }
}

/// CSS dropIn。サイズ固定の Canvas だけ動かす（親レイアウトに影響しない）
private struct DropO: View {
    @State private var born = Date()
    private let em: CGFloat = 76

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = min(1.05, timeline.date.timeIntervalSince(born))
            let pose = dropPose(t)
            Canvas { ctx, size in
                let d = min(size.width, size.height)
                let cx = size.width / 2
                let cy = size.height / 2 + pose.ty * em
                if pose.trails {
                    drawTrail(ctx, cx: cx, cy: cy, d: d, ratio: 0.095 / 0.38, up: 0.39, opacity: 0.5)
                    drawTrail(ctx, cx: cx, cy: cy, d: d, ratio: 0.072 / 0.38, up: 0.52, opacity: 0.34)
                    drawTrail(ctx, cx: cx, cy: cy, d: d, ratio: 0.053 / 0.38, up: 0.64, opacity: 0.22)
                }
                let xform = CGAffineTransform.identity
                    .translatedBy(x: cx, y: cy + d / 2)
                    .scaledBy(x: pose.sx, y: pose.sy)
                    .translatedBy(x: -cx, y: -(cy + d / 2))
                let ball = Path(ellipseIn: CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d))
                    .applying(xform)
                ctx.fill(ball, with: .color(DD.paper))
            }
        }
        .frame(width: em * 0.38, height: em * 0.38)
        .padding(.horizontal, em * 0.17)
    }

    private func drawTrail(
        _ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, d: CGFloat,
        ratio: CGFloat, up: CGFloat, opacity: Double
    ) {
        let r = d * ratio / 2
        let y = cy - up * em
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r, y: y - r, width: r * 2, height: r * 2)),
            with: .color(DD.paper.opacity(opacity))
        )
    }

    private func dropPose(_ t: Double) -> (ty: CGFloat, sx: CGFloat, sy: CGFloat, trails: Bool) {
        let p = t / 1.05
        if p < 0.30 { return (-4.4 * (1 - p / 0.30), 1, 1, true) }
        if p < 0.34 { return (0, 1.24, 0.72, false) }
        if p < 0.38 { return (0, 0.93, 1.12, false) }
        if p < 0.55 { return (-0.85 * ((p - 0.38) / 0.17), 1, 1, false) }
        if p < 0.68 { return (-0.85 * (1 - (p - 0.55) / 0.13), 1.16, 0.82, false) }
        if p < 0.71 { return (0, 0.96, 1.07, false) }
        if p < 0.82 { return (-0.3 * ((p - 0.71) / 0.11), 1, 1, false) }
        if p < 0.91 { return (-0.3 * (1 - (p - 0.82) / 0.09), 1.08, 0.92, false) }
        if p < 0.96 { return (0, 0.99, 1.02, false) }
        return (0, 1, 1, false)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
