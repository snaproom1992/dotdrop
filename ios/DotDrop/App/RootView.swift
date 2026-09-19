import SwiftUI
import UIKit
import AVFoundation
import DotDropEngine

/// HTML の overlay / header / canvas の重ね方に対応
struct RootView: View {
    @State private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var safeTop: CGFloat = 0
    @State private var safeBot: CGFloat = 0
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
                    safeTop: safeTop,
                    safeBottom: safeBot,
                    height: size.height,
                    onPlay: { session.startFreePlay() },
                    onTutorial: { session.openTutorialList() }
                )

            case .playing:
                ZStack {
                    BoardCanvas(session: session, fit: fit)
                    GameHUD(session: session, safeTop: safeTop, width: size.width)
                }
                .coordinateSpace(name: "board")

            case .result:
                ResultOverlay(
                    session: session,
                    width: size.width,
                    safeTop: safeTop,
                    safeBottom: safeBot,
                    onRetry: { session.startFreePlay() },
                    onTitle: { session.openTitle() }
                )
            case .tutorialList, .tutorialResult:
                TutorialOverlay(session: session, safeTop: safeTop, safeBottom: safeBot)
            }

            if session.isPaused {
                DD.brown.opacity(0.94).ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("PAUSE").font(DD.bold(40)).kerning(-1.6)
                    Button("つづける") { session.resume() }
                        .font(DD.bold(18)).padding(.horizontal, 40).padding(.vertical, 16)
                        .background(DD.red).clipShape(Capsule())
                    Button("タイトルへ") { session.openTitle() }.font(DD.bold(13)).frame(minHeight: 44)
                }.foregroundStyle(DD.paper)
            }

            if session.showResetSheet {
                ResetSheet(
                    session: session,
                    safeBottom: safeBot,
                    onReset: {
                        session.showResetSheet = false
                        session.restart()
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
        .onAppear { session.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, value in session.reduceMotion = value }
        .onChange(of: scenePhase) { _, phase in
            GameAudio.shared.isAppActive = phase == .active
            if phase == .active { refreshSafeArea() }
            else {
                session.pause()
                GameAudio.shared.suspend()
                GameHaptics.cancel()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               type == AVAudioSession.InterruptionType.began.rawValue { session.pause() }
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
        if abs(safeTop - insets.top) > 0.5 {
            safeTop = insets.top
        }
        if abs(safeBot - insets.bottom) > 0.5 {
            safeBot = insets.bottom
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let again = ScreenSafeArea.insets
            if abs(safeTop - again.top) > 0.5 { safeTop = again.top }
            if abs(safeBot - again.bottom) > 0.5 { safeBot = again.bottom }
        }
    }
}

#Preview {
    RootView()
}
