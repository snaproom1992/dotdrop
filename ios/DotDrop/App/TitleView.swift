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
        // h1: 76px, letter-spacing -.06em, DOT の O は .38em / 左右 .17em
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("D")
                DropO()
                Text("T")
            }
            Text("DROP")
        }
        .font(.system(size: 76, weight: .bold))
        .foregroundStyle(DD.paper)
        .tracking(-76 * 0.06)
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

/// CSS dropIn / trail
struct DropO: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            let t = min(1.05, timeline.date.timeIntervalSince(start))
            let pose = dropPose(t)
            ZStack {
                if pose.trails {
                    trail(0.095, 0.39, 0.5)
                    trail(0.072, 0.52, 0.34)
                    trail(0.053, 0.64, 0.22)
                }
                Circle()
                    .fill(DD.paper)
                    .scaleEffect(x: pose.sx, y: pose.sy, anchor: .bottom)
                    .offset(y: 76 * pose.ty)
            }
            .frame(width: 76 * 0.38, height: 76 * 0.38)
        }
        .padding(.horizontal, 76 * 0.17)
        .offset(y: -76 * 0.17)
        .onAppear { start = Date() }
    }

    private func trail(_ size: CGFloat, _ bottom: CGFloat, _ opacity: Double) -> some View {
        Circle()
            .fill(DD.paper.opacity(opacity))
            .frame(width: 76 * size, height: 76 * size)
            .offset(y: -76 * bottom)
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
