import SwiftUI
import DotDropEngine

/// HTML の overlay / header / canvas の重ね方に対応
struct RootView: View {
    @StateObject private var session = GameSession()

    var body: some View {
        // web の innerWidth/innerHeight と同じく、セーフエリア込みの全画面サイズで fit する
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBot = geo.safeAreaInsets.bottom
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
                session.applyFit(fit)
                if session.screen == .title { session.openTitle() }
            }
        }
        .ignoresSafeArea() // ← これがないと geo.size が縮小し、盤面と HUD がズレる
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
