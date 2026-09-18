import SwiftUI

/// `#start` の DOT の O。CSS `.38em` / dropIn / trail に対応
struct DropO: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let pose = dropPose(min(t, 1.05))
            ZStack {
                if pose.trails {
                    trail(size: 0.095, bottom: 0.39, opacity: 0.5)
                    trail(size: 0.072, bottom: 0.52, opacity: 0.34)
                    trail(size: 0.053, bottom: 0.64, opacity: 0.22)
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

    private func trail(size: CGFloat, bottom: CGFloat, opacity: Double) -> some View {
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

/// タイトル画面
struct TitleView: View {
    @ObservedObject var session: GameSession
    var onPlay: () -> Void
    var onTutorial: () -> Void

    var body: some View {
        ZStack {
            DD.brown.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
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
                .tracking(-4.5)

                HStack(spacing: 14) {
                    Rectangle().fill(DD.red).frame(width: 22, height: 22)
                    Circle().fill(DD.blue).frame(width: 22, height: 22)
                    Triangle().fill(DD.mustard).frame(width: 26, height: 22)
                }
                .padding(.top, 22)

                Button(action: onPlay) {
                    Text("はじめる")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DD.paper)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        .background(DD.red)
                        .clipShape(Capsule())
                }
                .padding(.top, 28)

                Button(action: onTutorial) {
                    VStack(spacing: 9) {
                        Text("あそびかた")
                            .font(.system(size: 16, weight: .bold))
                        HStack(spacing: 5) {
                            ForEach(0..<8, id: \.self) { i in
                                // クリア数に応じて左から点灯（暫定）
                                let on = i < session.tutorialCleared.count
                                Circle()
                                    .fill(on ? DD.red : DD.paper.opacity(0.25))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .foregroundStyle(DD.paper)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 30)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(DD.paper, lineWidth: 2))
                }
                .padding(.top, 14)

                Spacer(minLength: 40)
            }
        }
    }
}
