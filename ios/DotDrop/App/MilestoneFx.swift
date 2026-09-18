import SwiftUI

/// A-1：1回の放出で100点ごとに出る「数字ドン」。
///
/// Web の `MILESTONES` / `checkMilestone` / `drawMilestone` / `milestoneVisible` に当たる。
/// このゲームの快感の中心なので、数字・色・timing は Web と1つも変えないこと。
struct MilestoneFx {

    /// いま出ている数字ドン
    struct Active {
        var level: Int          // 1〜10（表示は level * 100 点）
        var t: Double = 0
        var color: FxColor
    }

    private(set) var active: Active?
    /// この放出で何段まで出したか。launch のたびに 0 に戻す
    private(set) var reached = 0

    // MARK: - 色（Web と同じ）
    // 100〜400は赤、600〜900は青、500と1000は赤・黄・青が高速で入れ替わる。
    // 黄色単色はフィーバー中に見えないので使わない。

    static func isCycle(_ level: Int) -> Bool { level == 5 || level == 10 }

    static func color(for level: Int) -> FxColor {
        if isCycle(level) { return .cycle }
        return .solid(level >= 6 ? DD.blue : DD.red)
    }

    // MARK: - 放出のたびに呼ぶ

    mutating func reset() {
        reached = 0
        active = nil
    }

    /// 毎フレーム、物理を進めたあとに呼ぶ。
    /// `pot` はいま溜めているポイント、`shotScore` はこの放出で入ったスコア。
    /// 段が上がったら true を返すので、呼ぶ側で音と振動を鳴らす。
    mutating func check(pot: Int, shotScore: Int, juice: inout GameJuice) -> Int? {
        let value = max(pot, shotScore)
        let level = min(10, value / 100)
        guard level > reached else { return nil }
        reached = level

        let col = Self.color(for: level)
        active = Active(level: level, t: 0, color: col)
        juice.addShake(0.2 + Double(level) * 0.04)
        juice.addHitStop(0.06 + Double(level) * 0.01)
        juice.flashEdge(col, width: 14 + Double(level) * 2 + (Self.isCycle(level) ? 8 : 0))
        return level
    }

    mutating func tick(real: Double) {
        guard active != nil else { return }
        active!.t += real
        if active!.t > 1.1 { active = nil }
    }

    // MARK: - 描画

    /// 数字ドンが出ている強さ（0〜1）。
    /// **背景の大きな数字は、この分だけ消すこと**（大きな数字を重ねない、というルール）
    var visible: Double {
        guard let m = active, m.t <= 1.1 else { return 0 }
        if m.t < 0.08 { return m.t / 0.08 }
        if m.t > 0.8 { return max(0, 1 - (m.t - 0.8) / 0.3) }
        return 1
    }

    /// BoardCanvas の流儀に合わせて、画面の座標で描く。
    /// `center` は数字を置く位置（画面座標）、`s` は台の拡大率。
    /// 呼ぶのは**いちばん最後**（釘・受け皿・玉より手前）。
    func draw(ctx: GraphicsContext, center: CGPoint, scale s: Double, font: (Double) -> Font) {
        guard let m = active, m.t <= 1.1 else { return }

        // ドン：2.4倍で入って1倍まで縮み、そのあと少しだけ揺り返す
        let inK = min(1, m.t / 0.12)
        let pop: Double
        if m.t < 0.12 {
            pop = 2.4 - 1.4 * Self.ease(inK)
        } else if m.t < 0.22 {
            pop = 1 + 0.08 * sin((m.t - 0.12) / 0.1 * .pi)
        } else {
            pop = 1
        }
        let alpha = m.t > 0.8 ? 1 - (m.t - 0.8) / 0.3 : 1
        let col = m.color.resolved(t: m.t)
        let base: Double = m.level >= 10 ? 130 : 150
        let size = base * pop * s

        var c = ctx
        c.opacity = max(0, alpha)
        let number = Text("\(m.level * 100)").font(font(size))
        // 影でくっきり（こげ茶の背景でも赤や青が沈まない）
        c.draw(
            number.foregroundColor(DD.ink.opacity(0.55)),
            at: CGPoint(x: center.x + 4 * s * pop, y: center.y + 6 * s * pop), anchor: .center
        )
        c.draw(number.foregroundColor(col), at: center, anchor: .center)
        c.draw(
            Text("POINTS").font(font(14 * pop * s)).foregroundColor(col),
            at: CGPoint(x: center.x, y: center.y + base * 0.55 * pop * s), anchor: .center
        )
    }

    /// Web の `ease`（easeOutCubic）
    private static func ease(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
}
