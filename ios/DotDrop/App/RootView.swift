import SwiftUI
import UIKit
import DotDropEngine

/// HTML の overlay / header / canvas の重ね方に対応
struct RootView: View {
    @State private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var safeTop: CGFloat = 59
    @State private var safeBot: CGFloat = 34
    @State private var viewSize: CGSize = .zero

    var body: some View {
        let size = resolvedSize
        let fit = BoardFit.compute(viewSize: size, safeTop: safeTop, safeBottom: safeBot)

        ZStack {
            // feverLeft を読むことで、フィーバー突入時に背景が更新される
            DD.bg(fever: session.feverLeft > 0 && session.screen == .playing)

            switch session.screen {
            case .title:
                TitleView(
                    session: session,
                    onPlay: { session.startFreePlay() },
                    onTutorial: {}
                )

            case .playing:
                ZStack {
                    BoardCanvas(session: session, fit: fit)
                    GameHUD(session: session, safeTop: safeTop, width: size.width)
                }

            case .result:
                ResultOverlay(
                    session: session,
                    width: size.width,
                    onRetry: { session.startFreePlay() },
                    onTitle: { session.openTitle() }
                )
            }

            if session.showResetSheet {
                ResetSheet(
                    session: session,
                    safeBottom: safeBot,
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { geo in
                Color.clear
                    .task(id: sizeKey(geo.size)) {
                        updateSize(geo.size)
                        refreshSafeArea()
                        applyCurrentFit()
                    }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSafeArea() }
        }
        .onChange(of: safeTop) { _, _ in applyCurrentFit() }
        .onChange(of: safeBot) { _, _ in applyCurrentFit() }
    }

    private var resolvedSize: CGSize {
        if viewSize.width > 0, viewSize.height > 0 { return viewSize }
        return UIScreen.main.bounds.size
    }

    private func sizeKey(_ size: CGSize) -> Int {
        Int(size.width.rounded()) &* 10_000 &+ Int(size.height.rounded())
    }

    private func applyCurrentFit() {
        session.applyFit(
            BoardFit.compute(viewSize: resolvedSize, safeTop: safeTop, safeBottom: safeBot),
            safeTop: safeTop
        )
    }

    private func updateSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard abs(size.width - viewSize.width) > 0.5 || abs(size.height - viewSize.height) > 0.5 else { return }
        viewSize = size
    }

    private func refreshSafeArea() {
        let insets = ScreenSafeArea.insets
        if insets.top > 0, abs(safeTop - insets.top) > 0.5 {
            safeTop = insets.top
        }
        if insets.bottom > 0, abs(safeBot - insets.bottom) > 0.5 {
            safeBot = insets.bottom
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let again = ScreenSafeArea.insets
            if again.top > 0, abs(safeTop - again.top) > 0.5 { safeTop = again.top }
            if again.bottom > 0, abs(safeBot - again.bottom) > 0.5 { safeBot = again.bottom }
        }
    }
}

#Preview {
    RootView()
}
