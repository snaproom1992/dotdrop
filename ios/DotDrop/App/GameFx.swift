import SwiftUI
import UIKit
import DotDropEngine

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
        /// 帯に収まる大きさ。**出すときに1回だけ測る。**
        /// 毎フレーム測り直すと、文字組みが1フレームに何十回も走って重い
        var wordSize: Double = 40
        var subSize: Double = 14
        var wordWidth: Double = 0

        /// 本家と同じ詰め方：まず見出しを2ずつ、それでも入らなければ説明を1ずつ縮める。
        /// 62 は左の余白16＋区切りの前後14×2＋右の余白
        mutating func fit(screenWidth: Double) {
            wordSize = 40
            subSize = 14
            func total() -> Double {
                TextWidth.of(word, wordSize) + TextWidth.of(sub, subSize) + 62
            }
            while wordSize > 20, total() > screenWidth { wordSize -= 2 }
            while subSize > 11, total() > screenWidth { subSize -= 1 }
            wordWidth = TextWidth.of(word, wordSize)
        }
    }

    /// 文字の幅を測る。**「文字数 × 係数」で見積もらないこと。**
    /// 日本語は1文字がほぼ倍の幅なので、説明文の幅が大きく外れる
    enum TextWidth {
        private static var cache: [String: Double] = [:]
        static func of(_ text: String, _ size: Double) -> Double {
            guard !text.isEmpty else { return 0 }
            let key = "\(Int(size * 10))|\(text)"
            if let w = cache[key] { return w }
            let font = UIFont(name: "HelveticaNeue-Bold", size: CGFloat(size))
                ?? .boldSystemFont(ofSize: CGFloat(size))
            let w = Double((text as NSString).size(withAttributes: [.font: font]).width)
            if cache.count > 200 { cache.removeAll() }
            cache[key] = w
            return w
        }
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
    /// 本家の `SHAPE`。釘に当たったときの「+N」や、そこから飛ぶ玉の色。
    ///
    /// **フィーバー用の色を必ず持たせること。**フィーバー中は背景が黄なので、
    /// ▲の黄と、小さい釘のクリームは、そのままだと背景と同じ色になって消える
    static func shapeColor(_ kind: PegKind, fever: Bool) -> Color {
        switch kind {
        case .square: return DD.red
        case .blue: return DD.blue
        case .tri: return DD.highlight(fever: fever)
        case .dot: return DD.fg(fever: fever)
        }
    }

    static func multColor(_ m: Int, fever: Bool) -> Color {
        if m >= 5 { return DD.red }
        if m == 3 { return fever ? DD.ink : DD.mustard }
        if m == 1 { return DD.fg(fever: fever) }
        return DD.fg(fever: fever).opacity(0.45)
    }
}
