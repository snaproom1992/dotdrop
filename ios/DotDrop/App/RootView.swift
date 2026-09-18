import SwiftUI
import DotDropEngine

/// HTML の overlay 構成に対応するルート
struct RootView: View {
    @StateObject private var session = GameSession()

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBot = geo.safeAreaInsets.bottom
            let fit = BoardFit.compute(viewSize: geo.size, safeTop: safeTop, safeBottom: safeBot)

            ZStack {
                DD.bg(fever: session.fever && session.screen == .playing)
                    .ignoresSafeArea()

                switch session.screen {
                case .title:
                    TitleView(
                        session: session,
                        onPlay: { session.startFreePlay() },
                        onTutorial: {
                            // あそびかた一覧は次段。いまはフリープレイへ誘導せず一覧プレースホルダ
                            session.showBanner("あそびかた", "一覧は次の更新で接続します", DD.paper)
                            // 暫定：まだネイティブ未接続なので何もしない（ボタンは置いてある）
                        }
                    )

                case .playing:
                    ZStack(alignment: .top) {
                        BoardCanvas(session: session, fit: fit)
                            .ignoresSafeArea()
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
            .onAppear {
                session.applyFit(fit)
                if session.screen == .title { session.openTitle() }
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
