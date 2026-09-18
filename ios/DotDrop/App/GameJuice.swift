import SwiftUI

/// A-3：当たった瞬間の手応え（止め・揺れ・スロー）と、画面のふちの光。
///
/// Web の `hitStop` / `shake` / `slowPulse` / `timeScale` / `edge` に当たる。
/// GameSession が1つ持って、毎フレーム `tick(real:)` を呼ぶ。
struct GameJuice {

    // MARK: - 状態

    /// 時間を止めている残り秒。0より大きい間は物理を進めない
    var hitStop: Double = 0
    /// 画面の揺れの強さ（0〜。1.1でPERFECT級）
    var shake: Double = 0
    /// スローの残り秒。この間 timeScale が .3 へ寄る
    var slowPulse: Double = 0
    /// いまの時間の倍率。1が通常、.3でスロー
    private(set) var timeScale: Double = 1
    /// 画面のふちの光
    var edge: EdgeGlow?

    struct EdgeGlow {
        var color: FxColor
        var t: Double = 0
        var width: Double = 16
    }

    // MARK: - 積む（Web の Math.max と同じで、強いほうが勝つ）

    mutating func addHitStop(_ v: Double) { hitStop = max(hitStop, v) }
    mutating func addShake(_ v: Double) { shake = max(shake, v) }
    mutating func flashEdge(_ color: FxColor, width: Double = 16) {
        edge = EdgeGlow(color: color, t: 0, width: width)
    }

    // MARK: - 毎フレーム

    /// `real` は実時間の差分（秒）。
    /// 戻り値が「物理を進めてよい秒数」。0なら止めている最中なので進めない。
    ///
    /// Web の順番をそのまま守る：
    ///   1. slowPulse を減らして、slow なら timeScale を .3 へ寄せる
    ///   2. hitStop が残っていれば減らすだけで、物理は進めない
    ///   3. 揺れは実時間で減衰（スローの影響を受けない）
    mutating func tick(real: Double, slowHint: Bool = false) -> Double {
        var slow = slowHint
        if slowPulse > 0 {
            slowPulse -= real
            slow = true
        }
        timeScale += ((slow ? 0.3 : 1) - timeScale) * min(1, real * 12)

        var advance = 0.0
        if hitStop > 0 {
            hitStop -= real
        } else {
            advance = real * timeScale
        }

        shake = max(0, shake - real * 1.6)
        if edge != nil { edge!.t += real }
        if let e = edge, e.t >= 0.9 { edge = nil }
        return advance
    }

    // MARK: - 描画に渡すもの

    /// 台を描く前にずらす量。Web の `(Math.random() - .5) * 14 * shake`
    var shakeOffset: CGSize {
        guard shake > 0 else { return .zero }
        return CGSize(
            width: (Double.random(in: 0...1) - 0.5) * 14 * shake,
            height: (Double.random(in: 0...1) - 0.5) * 14 * shake
        )
    }

    /// 画面のふちの光。**台の変形（拡大・ずらし）の外側**で、いちばん最後に描く
    func drawEdge(ctx: GraphicsContext, size: CGSize) {
        guard let e = edge, e.t < 0.9 else { return }
        var c = ctx
        c.opacity = 1 - e.t / 0.9
        c.stroke(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(e.color.resolved(t: e.t)),
            lineWidth: e.width
        )
    }
}

/// 単色か、赤・黄・青の高速入れ替えか。
/// Web の `resolveColor` / `cycleColor` に当たる（500点と1000点だけ入れ替わる）
enum FxColor {
    case solid(Color)
    case cycle

    private static let cycleColors: [Color] = [DD.red, DD.mustard, DD.blue]

    func resolved(t: Double) -> Color {
        switch self {
        case .solid(let c): return c
        case .cycle:
            let i = Int(floor(t * 12)) % Self.cycleColors.count
            return Self.cycleColors[(i + Self.cycleColors.count) % Self.cycleColors.count]
        }
    }
}
