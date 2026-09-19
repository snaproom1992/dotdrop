import SwiftUI
import UIKit

/// `#start` overlay（justify-content: safe center）
struct TitleView: View {
    var session: GameSession
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var onPlay: () -> Void
    var onTutorial: () -> Void

    @State private var showSettings = false

    var body: some View {
        ZStack {
            DD.brown
            GeometryReader { geo in
              ScrollView {
               VStack(spacing: 0) {
                // 間の取り方は本家の数字に合わせない。**詰まって見えるかどうかで決める。**
                // 全部を似た間隔（22/28/20）にしていたら、まとまりの差が出ず、
                // 4つが一つの塊に見えて詰まっていた。3段に分ける：
                //   タイトルと■●▲は同じまとまり（近い）
                //   そこから操作へは、いちばん大きく空ける（22 → 56 → 28）
                //   2つのボタンは組だが、くっつけない
                titleBlock
                shapes
                    .padding(.top, 22)
                startButton
                    .padding(.top, 56)
                tutorialButton
                    .padding(.top, 28)
               }
               .padding(24)
               .frame(maxWidth: .infinity, minHeight: geo.size.height)
              }
              .scrollIndicators(.hidden)
            }
            // 設定は右上に小さく。「はじめる」「あそびかた」の2つは主役のまま動かさない
            Button { showSettings = true } label: {
                SettingsButton()          // 44×44。指で押せる大きさ
                    .contentShape(Circle())
            }
            .accessibilityLabel("設定。音・振動・演出")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // 端との空きは20。画面の中の数字（持ち玉・スコア）と同じ空け方にそろえる。
            // 8 だと画面のふちに貼りついて見える
            .padding(.trailing, 20)
            .padding(.top, safeTop + 8)

            if showSettings {
                SettingsSheet(safeBottom: safeBottom) { showSettings = false }
                    .zIndex(7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleBlock: some View {
        DropLogo()
            .accessibilityLabel("DOT DROP")
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
                .frame(height: DD.lineBox(18))
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
                    .frame(height: DD.lineBox(16))
                HStack(spacing: 5) {
                    ForEach(TutorialStep.all) { step in
                        Circle()
                            .fill(session.tutorialCleared.contains(step.id) ? DD.red : DD.paper.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .foregroundStyle(DD.paper)
            .padding(.vertical, 15)
            .padding(.horizontal, 30)
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(DD.paper, lineWidth: 2))
        }
    }
}

/// CSS dropIn。サイズ固定の Canvas だけ動かす（親レイアウトに影響しない）
private struct DropLogo: View {
    @State private var born = Date()
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let em: CGFloat = 76

    var body: some View {
        // The extra area belongs to the drawing surface, not to the logo's layout.
        // This lets the ball arrive from above without clipping it to a 29pt box.
        Color.clear.frame(width: 260, height: em * 1.8)
          .overlay(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: finished || reduceMotion)) { timeline in
              Canvas { ctx, size in
                let t = reduceMotion ? 1.05 : min(1.05, timeline.date.timeIntervalSince(born))
                let pose = dropPose(t)
                let extra = size.height - em * 1.8
                let font = UIFont(name: "HelveticaNeue-Bold", size: em) ?? .boldSystemFont(ofSize: em)
                let baseline = extra + (em * 0.9 - font.lineHeight) / 2 + font.ascender
                let bounds = CGSize(width: 1_000, height: 1_000)
                func resolve(_ string: String, kern: CGFloat = 0) -> GraphicsContext.ResolvedText {
                    ctx.resolve(Text(string).font(DD.bold(em)).kerning(kern).foregroundColor(DD.paper))
                }
                let dText = resolve("D"), tText = resolve("T")
                let dWidth = dText.measure(in: bounds).width
                let tWidth = tText.measure(in: bounds).width
                let diameter = em * 0.38, gap = em * (0.17 - 0.06)
                let lineWidth = dWidth + gap + diameter + gap + tWidth
                let left = (size.width - lineWidth) / 2
                func drawText(_ text: GraphicsContext.ResolvedText, x: CGFloat, baseline: CGFloat) {
                    ctx.draw(text, at: CGPoint(x: x, y: baseline - text.firstBaseline(in: bounds)), anchor: .topLeading)
                }
                drawText(dText, x: left, baseline: baseline)
                drawText(tText, x: left + dWidth + gap + diameter + gap, baseline: baseline)
                let drop = resolve("DROP", kern: -em * 0.06)
                drawText(drop, x: (size.width - drop.measure(in: bounds).width) / 2, baseline: baseline + em * 0.9)
                let cx = left + dWidth + gap + diameter / 2
                let bottom = baseline - em * 0.17 + pose.ty * em
                var ballContext = ctx
                ballContext.translateBy(x: cx, y: bottom)
                ballContext.scaleBy(x: pose.sx, y: pose.sy)
                ballContext.fill(Path(ellipseIn: CGRect(x: -diameter / 2, y: -diameter, width: diameter, height: diameter)), with: .color(DD.paper))
                for (diam, up, opacity) in [(0.095, 0.39, 0.5), (0.072, 0.52, 0.34), (0.053, 0.64, 0.22)] {
                    let r = em * diam * pose.trail / 2
                    let y = -em * (up + diam / 2)
                    ballContext.fill(Path(ellipseIn: CGRect(x: -r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(DD.paper.opacity(opacity)))
                }
              }
            }
            .frame(height: em * 6.5)
            .allowsHitTesting(false)
          }
          .task {
            born = Date()
            try? await Task.sleep(for: .seconds(1.05))
            guard !Task.isCancelled else { return }
            finished = true
          }
    }

    private func dropPose(_ t: Double) -> (ty: CGFloat, sx: CGFloat, sy: CGFloat, trail: CGFloat) {
        let frames: [(Double, Double, Double, Double)] = [
            (0, -4.4, 1, 1), (0.30, 0, 1, 1), (0.34, 0, 1.24, 0.72),
            (0.38, 0, 0.93, 1.12), (0.55, -0.85, 1, 1), (0.68, 0, 1.16, 0.82),
            (0.71, 0, 0.96, 1.07), (0.82, -0.3, 1, 1), (0.91, 0, 1.08, 0.92),
            (0.96, 0, 0.99, 1.02), (1, 0, 1, 1)
        ]
        let p = max(0, min(1, t / 1.05))
        let i = min(frames.count - 2, max(0, (frames.firstIndex { $0.0 > p } ?? frames.count - 1) - 1))
        let a = frames[i], b = frames[i + 1]
        let u = (p - a.0) / (b.0 - a.0)
        let curve: (Double, Double, Double, Double)
        switch i {
        case 0, 4, 7: curve = (0.45, 0, 0.9, 0.4)
        case 3, 6: curve = (0.15, 0.7, 0.4, 1)
        default: curve = (0.25, 0.1, 0.25, 1)
        }
        let k = bezier(u, curve)
        let trail = 1 - bezier(max(0, min(1, (p - 0.27) / 0.09)), (0.25, 0.1, 0.25, 1))
        return (CGFloat(a.1 + (b.1 - a.1) * k), CGFloat(a.2 + (b.2 - a.2) * k), CGFloat(a.3 + (b.3 - a.3) * k), CGFloat(trail))
    }

    private func bezier(_ x: Double, _ c: (Double, Double, Double, Double)) -> Double {
        func axis(_ t: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<18 {
            let mid = (lo + hi) / 2
            if axis(mid, c.0, c.2) < x { lo = mid } else { hi = mid }
        }
        return axis((lo + hi) / 2, c.1, c.3)
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
