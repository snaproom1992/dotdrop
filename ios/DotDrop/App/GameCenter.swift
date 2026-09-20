import GameKit
import SwiftUI
import UIKit

/// 世界ランキング（Game Center）。
///
/// **遊ぶこと自体には一切関わらせない。**サインインしなくても、圏外でも、
/// ゲームはこれまでどおり最後まで遊べる。世界ランキングを見るときだけ通信する。
///
/// 名前は Game Center のものをそのまま使う。**アプリで名前を聞かないこと。**
/// 自分で聞くと「個人情報を集めている」ことになり、プライバシーの申告が変わる
/// （Apple が持つぶんは、こちらの申告に含めなくてよい）。
///
/// ランキングを1つ作ると、友達への「チャレンジ」はコードなしで付いてくる。
@MainActor
@Observable
final class GameCenter {
    static let shared = GameCenter()

    /// App Store Connect のランキング「High Score」の ID。
    /// **一字でも違うとスコアが届かず、黙って捨てられる**
    static let leaderboardID = "com.snaproom.dotdrop.highscore"

    private(set) var signedIn = false
    private(set) var entries: [Entry] = []
    private(set) var myEntry: Entry?
    private(set) var state: State = .idle

    enum State: Equatable { case idle, loading, ready, failed }

    struct Entry: Identifiable, Equatable {
        var id: Int { rank }
        var rank: Int
        var name: String
        var score: Int
        var isMe: Bool
    }

    private var board: GKLeaderboard?

    private init() {}

    // MARK: - サインイン

    /// 起動時に1回だけ。断られても何も起きない（ゲームはそのまま遊べる）
    func start() {
        #if DEBUG
        // 撮影中にサインインの帯が降りてくると画面が写り込む
        if ScreenshotMode.isOn { return }
        #endif
        guard !GKLocalPlayer.local.isAuthenticated else { signedIn = true; return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    // サインインの画面は Apple が出す。いちばん手前の画面から出す
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.signedIn = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - スコアを送る

    /// 1ゲーム終わるたびに送る。失敗しても黙って捨てる（遊びを止めない）
    func submit(_ score: Int) {
        guard signedIn, score > 0 else { return }
        GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID]
        ) { _ in }
    }

    // MARK: - 読み込む

    /// きろくの板で「世界」に切り替えたときに呼ぶ
    func load(top count: Int = 20) {
        guard signedIn else { state = .failed; return }
        state = .loading
        Task {
            do {
                let board: GKLeaderboard
                if let cached = self.board { board = cached }
                else { board = try await Self.fetchBoard() }
                self.board = board
                let (local, rows, _) = try await board.loadEntries(
                    for: .global, timeScope: .allTime, range: NSRange(location: 1, length: count)
                )
                let me = local.map(Self.entry(from:))
                self.entries = rows.map(Self.entry(from:))
                self.myEntry = me
                self.state = .ready
            } catch {
                self.state = .failed
            }
        }
    }

    private enum Failure: Error { case noLeaderboard }

    private static func fetchBoard() async throws -> GKLeaderboard {
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
        guard let board = boards.first else { throw Failure.noLeaderboard }
        return board
    }

    private static func entry(from e: GKLeaderboard.Entry) -> Entry {
        Entry(rank: e.rank,
              name: e.player.displayName,
              score: e.score,
              isMe: e.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID)
    }

    // MARK: - 小物

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}
