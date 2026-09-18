import SwiftUI
import DotDropEngine

/// HTML の overlay / header / canvas の重ね方に対応
struct RootView: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    /// GeometryReader + ignoresSafeArea だと insets が 0 になるので、ウィンドウから読む
    @State private var safeTop: CGFloat = ScreenSafeArea.top
    @State private var safeBot: CGFloat = ScreenSafeArea.bottom

    var body: some View {
        // web の innerWidth/innerHeight と同じく、セーフエリア込みの全画面サイズで fit する
        GeometryReader { geo in
            let fit = BoardFit.compute(
                viewSize: geo.size,
                safeTop: safeTop,
                safeBottom: safeBot
            )

            ZStack {
                DD.bg(fever: session.fever && session.screen == .playing)

                switch session.screen {
                case .title:
                    TitleView(
                        session: session,
                        onPlay: { session.startFreePlay() },
                        onTutorial: {
                            // 次段で一覧接続
                        }
                    )

                case .playing:
                    ZStack {
                        BoardCanvas(session: session, fit: fit)
                        GameHUD(session: session, safeTop: safeTop)
                    }
                    .onAppear { session.applyFit(fit) }
                    .onChange(of: fit.logicalHeight) { _, _ in
                        session.applyFit(fit)
                    }

                case .result:
                    ResultOverlay(
                        session: session,
                        onRetry: { session.startFreePlay() },
                        onTitle: { session.openTitle() }
                    )
                }

                if session.showResetSheet {
                    ResetSheet(
                        session: session,
                        onReset: {
                            session.showResetSheet = false
                            session.startFreePlay()
                        },
                        onTitle: {
                            session.showResetSheet = false
                            session.openTitle()
                        }
                    )
                    .zIndex(7)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                refreshSafeArea()
                session.applyFit(fit)
                if session.screen == .title { session.openTitle() }
            }
            .onChange(of: geo.size) { _, _ in
                refreshSafeArea()
            }
        }
        .ignoresSafeArea() // 全画面サイズは必要。insets は ScreenSafeArea で別途取得
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSafeArea() }
        }
    }

    private func refreshSafeArea() {
        let apply = {
            let insets = ScreenSafeArea.insets
            // 起動直後はウィンドウ未準備で 0 のことがある。取れた値だけ反映
            if insets.top > 0 { safeTop = insets.top }
            if insets.bottom > 0 { safeBot = insets.bottom }
        }
        apply()
        // Web の fit() と同様、少し遅れて測り直す（ホーム画面起動などで高さが後から変わる）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: apply)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: apply)
    }
}

#Preview {
    RootView()
}
