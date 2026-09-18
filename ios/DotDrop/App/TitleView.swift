import SwiftUI

/// `#start` overlay（justify-content: safe center）
struct TitleView: View {
    @ObservedObject var session: GameSession
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
        // h1: 76px, letter-spacing -.06em, line-height .9
        // DOT の O は .38em / 左右 .17em / vertical-align:baseline / top:-.17em
        // レイアウト用の固定枠と、アニメ用の TimelineView を分ける（AttributeGraph cycle 防止）
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("D")
                DropOSlot()
                Text("T")
            }
            Text("DROP")
        }
        .font(.system(size: 76, weight: .bold))
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
                .font(.system(size: 18, weight: .bold))
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
                    .font(.system(size: 16, weight: .bold))
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

/// レイアウトだけ担当（サイズ固定）。アニメは overlay 内の DropO に閉じる。
private struct DropOSlot: View {
    private let em: CGFloat = 76

    var body: some View {
        Color.clear
            .frame(width: em * 0.38, height: 1)
            .padding(.horizontal, em * 0.17)
            .overlay(alignment: .bottom) {
                DropO()
                    .offset(y: -em * 0.17) // CSS top: -.17em
            }
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.bottom] }
    }
}

/// CSS dropIn / trail（描画のみ。親レイアウトを動かさない）
private struct DropO: View {
    @State private var start = Date()
    @State private var finished = false
    private let em: CGFloat = 76

    var body: some View {
        Group {
            if finished {
                Circle()
                    .fill(DD.paper)
                    .frame(width: em * 0.38, height: em * 0.38)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    let t = min(1.05, timeline.date.timeIntervalSince(start))
                    let pose = dropPose(t)
                    ZStack(alignment: .bottom) {
                        if pose.trails {
                            trail(0.095, 0.39, 0.5)
                            trail(0.072, 0.52, 0.34)
                            trail(0.053, 0.64, 0.22)
                        }
                        Circle()
                            .fill(DD.paper)
                            .frame(width: em * 0.38, height: em * 0.38)
                            .scaleEffect(x: pose.sx, y: pose.sy, anchor: .bottom)
                            .offset(y: em * pose.ty)
                    }
                    .frame(width: em * 0.38, height: em * 0.38, alignment: .bottom)
                }
            }
        }
        .frame(width: em * 0.38, height: em * 0.38, alignment: .bottom)
        .onAppear {
            start = Date()
            finished = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                finished = true
            }
        }
    }

    private func trail(_ size: CGFloat, _ bottom: CGFloat, _ opacity: Double) -> some View {
        Circle()
            .fill(DD.paper.opacity(opacity))
            .frame(width: em * size, height: em * size)
            .offset(y: -em * bottom)
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
