import SwiftUI

/// Web の floaters / flyers / catches に対応する演出オブジェクト
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

    /// `multColor` 相当
    static func multColor(_ m: Int, fever: Bool) -> Color {
        if m >= 5 { return DD.red }
        if m == 3 { return fever ? DD.ink : DD.mustard }
        if m == 1 { return DD.fg(fever: fever) }
        return DD.fg(fever: fever).opacity(0.45)
    }
}
