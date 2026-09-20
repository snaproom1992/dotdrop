import SwiftUI

@main
struct DotDropApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // 世界ランキングの用意。断られても、圏外でも、ゲームはそのまま遊べる
                .task { GameCenter.shared.start() }
        }
    }
}
