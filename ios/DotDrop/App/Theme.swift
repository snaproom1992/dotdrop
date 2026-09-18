import SwiftUI
import UIKit

/// `index.html` の `:root` / THEME に対応
enum DD {
    static let red = Color(hex: 0xD7141F)
    static let brown = Color(hex: 0x2A2322)
    static let mustard = Color(hex: 0xEAA83A)
    static let paper = Color(hex: 0xF2F1EE)
    static let ink = Color(hex: 0x1C1716)
    static let blue = Color(hex: 0x2456B8)
    static let pegNormal = Color(hex: 0x54463F)
    static let floorNormal = Color(hex: 0x1E1817)

    static func bg(fever: Bool) -> Color { fever ? mustard : brown }
    static func fg(fever: Bool) -> Color { fever ? ink : paper }
    static func peg(fever: Bool) -> Color { fever ? ink.opacity(0.26) : pegNormal }
    static func ball(fever: Bool) -> Color { fever ? ink : paper }
    /// 背景の大きな点数（THEME.*.big）
    static func big(fever: Bool) -> Color { fever ? ink.opacity(0.16) : paper.opacity(0.16) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Web の `fit()` と同じ。`viewSize` は **画面全体**（innerWidth / innerHeight）であること。
struct BoardFit: Equatable {
    var scale: CGFloat
    var ox: CGFloat
    var logicalHeight: Double
    var screenH: Double
    var bannerY: Double

    static func compute(viewSize: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> BoardFit {
        let LW = EngineLogical.w
        // web: h = max(400, innerHeight - safeB)  ※ safeT は引かない
        let h = max(400, viewSize.height - safeBottom)
        let scale = min(viewSize.width / LW, h / 640)
        let lh = Double(h / scale)
        let ox = (viewSize.width - LW * scale) / 2
        let screenH = Double(viewSize.height / scale)
        let bannerY = 116 + min(Double(safeTop / scale), 26)
        return BoardFit(scale: scale, ox: ox, logicalHeight: lh, screenH: screenH, bannerY: bannerY)
    }
}

enum EngineLogical {
    static let w: CGFloat = 360
}

/// `.ignoresSafeArea()` すると GeometryReader の insets が 0 になる。
/// Web の `env(safe-area-inset-*)` と同じ値を、ウィンドウから取る。
enum ScreenSafeArea {
    static var insets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return window?.safeAreaInsets ?? .zero
    }

    static var top: CGFloat { insets.top }
    static var bottom: CGFloat { insets.bottom }
}
