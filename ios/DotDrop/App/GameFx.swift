import SwiftUI

/// Web の floaters / flyers / catches / waves / milestone / edge / perfect に対応
enum GameFx {
    struct Floater {
        var x: Double
        var y: Double
        var text: String
        var color: Color
        var t: Double = 0
        var life: Double = 0.9
        var big: Bool = false
    }

    enum FlyerKind { case ball, score, minus }

    struct Flyer {
        var kind: FlyerKind
        var x0: Double
        var y0: Double
        var t: Double
        var color: Color
        var arc: Double
        var value: Int = 0
        var tx: Double = 0
        var ty: Double = 0
        var done: Bool = false
    }

    struct CatchBeam {
        var slot: Int
        var m: Int
        var t: Double = 0
    }

    struct Wave {
        var x: Double
        var y: Double
        var t: Double = 0
        var big: Bool
    }

    /// 帯。`t` でスライドイン／アウト
    struct Banner {
        var word: String
        var sub: String
        var color: Color
        var t: Double = 0
    }

    /// 100点ごとの数字ドン。color が nil なら cycle（赤・黄・青）
    struct Milestone {
        var level: Int
        var t: Double = 0
        var color: Color? // nil = cycle
    }

    struct Edge {
        var color: Color? // nil = cycle
        var t: Double = 0
        var width: Double = 16
    }

    struct PerfectFx {
        var t: Double = 0
    }

    struct SlotFlash {
        var t: Double = 0
        var slots: [Int]
    }

    static let cycleColors: [Color] = [DD.red, DD.mustard, DD.blue]

    static func isCycle(_ level: Int) -> Bool { level == 5 || level == 10 }

    static func milestoneColor(_ level: Int) -> Color? {
        if isCycle(level) { return nil }
        return level >= 6 ? DD.blue : DD.red
    }

    static func resolveColor(_ color: Color?, t: Double) -> Color {
        if let color { return color }
        let i = Int(floor(t * 12)) % 3
        return cycleColors[(i + 3) % 3]
    }

    /// 数字ドンが出ている強さ（0〜1）。背景の数字はこの分だけ消す
    static func milestoneVisible(_ m: Milestone?) -> Double {
        guard let m, m.t <= 1.1 else { return 0 }
        if m.t < 0.08 { return m.t / 0.08 }
        if m.t > 0.8 { return max(0, 1 - (m.t - 0.8) / 0.3) }
        return 1
    }

    static func perfectGlow(y: Double, fx: PerfectFx?) -> Double {
        guard let fx, fx.t <= 1.9 else { return 0 }
        let t = fx.t
        let wave = max(0, 1 - abs(y - (t * 820 - 60)) / 95)
        let pulse = t > 0.85
            ? max(0, 1 - (t - 0.85) / 1.05) * (0.4 + sin(t * 20) * 0.3)
            : 0
        return max(0, min(1, wave + pulse))
    }

    static func ease(_ t: Double) -> Double {
        1 - pow(1 - min(1, max(0, t)), 3)
    }

    /// `multColor` 相当
    static func multColor(_ m: Int, fever: Bool) -> Color {
        if m >= 5 { return DD.red }
        if m == 3 { return fever ? DD.ink : DD.mustard }
        if m == 1 { return DD.fg(fever: fever) }
        return DD.fg(fever: fever).opacity(0.45)
    }
}
