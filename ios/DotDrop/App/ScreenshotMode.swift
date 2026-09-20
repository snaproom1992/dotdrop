#if DEBUG
import Foundation
import SwiftUI
import DotDropEngine

/// スクリーンショットを自動で撮るための入口。**DEBUG のときしか存在しない。**
/// 製品のビルドには1行も入らない（`#if DEBUG` で丸ごと囲ってある）。
///
/// シミュレータに `-shot title` のように渡して起動すると、その画面を作って止まる。
/// 実際に遊ばないと作れない状態（フィーバー中など）を、撮るためだけに用意する。
enum ScreenshotMode {

    /// `-shot <名前>` で渡された名前。無ければ nil＝ふつうの起動
    static var name: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static var isOn: Bool { name != nil }

    /// 撮るときは、毎回まったく同じ盤面・同じ記録にする。
    /// そうしないと差分を見ても、変えた所のせいなのか運のせいなのか分からない
    static func seedStore() {
        let d = UserDefaults.standard
        let cal = Calendar(identifier: .gregorian)
        func day(_ ago: Int) -> Date {
            cal.date(byAdding: .day, value: -ago, to: Date()) ?? Date()
        }
        let ranking = [
            DDStore.RankEntry(score: 6420, stage: 11, shots: 33, date: day(0)),
            DDStore.RankEntry(score: 4120, stage: 8, shots: 28, date: day(1)),
            DDStore.RankEntry(score: 3040, stage: 7, shots: 26, date: day(3)),
            DDStore.RankEntry(score: 2010, stage: 6, shots: 25, date: day(6)),
            DDStore.RankEntry(score: 980, stage: 4, shots: 19, date: day(9)),
        ]
        if let data = try? JSONEncoder().encode(ranking) {
            d.set(data, forKey: "dotdrop-ranking")
        }
        d.set([
            "shotScore": 1010, "shotBalls": 9, "shotHits": 34, "ballGain": 240,
            "gameScore": 6420, "peakMoney": 41, "stage": 11,
        ], forKey: "dotdrop-records")
        d.set(6420, forKey: "dotdrop-best-game")
        d.set(["shot", "mult3", "gain", "square"], forKey: "dotdrop-tutorial")
    }

    /// 画面を作る。`RootView` から1回だけ呼ぶ
    @MainActor
    static func apply(to session: GameSession, name: String) {
        switch name {
        case "title", "records":
            session.screen = .title

        case "lessons":
            // 8つのやることが並ぶ画面。英語にしたとき、行がいちばん伸びる所
            session.openTutorialList()

        case "play", "aim", "fever":
            session.startFreePlay()
            session.engine.boardSeed = 7
            session.engine.setLayout(0, animate: false)
            session.money = 9
            session.moneyShown = 9
            session.score = 1240
            session.scoreShown = 1240
            session.engine.stage = 3
            session.boardShots = 2
            session.gauge = 74
            if name == "aim" {
                // 引ききった状態。弧が5本出る
                session.level = Engine.levels
                session.pullX = -46
                session.pullY = 118
            }
            if name == "fever" {
                session.engine.fever = true
                session.feverLeft = 3
                session.gauge = 0
                session.score = 3860
                session.scoreShown = 3860
            }

        case "result":
            session.startFreePlay()
            session.score = 5796
            session.scoreShown = 5796
            session.gameBestShot = 1010
            session.engine.stage = 9
            session.shots = 31
            session.finishGame()

        case "demo":
            // 動画用。**自分で打ち続ける。**simctl から指で触ることはできないので、
            // アプリ側で打つしかない。角度と強さは決め打ちの並びで、毎回同じ動きになる
            session.startFreePlay()
            playByItself(session)

        default:
            break
        }
    }

    /// 決め打ちの並びで打ち続ける。引く→ためる→はなす、を繰り返す
    @MainActor
    private static func playByItself(_ session: GameSession) {
        // (横に引く量, 下に引く量)。下に引くほど強い（上限130）
        let shots: [(Double, Double)] = [
            (-38, 118), (26, 124), (-8, 96), (44, 110), (-52, 128),
            (14, 86), (-24, 130), (36, 100), (-44, 112), (6, 122),
            (-16, 104), (48, 126), (-34, 92), (20, 116), (-6, 130),
        ]
        Task { @MainActor in
            var i = 0
            while i < 40, !Task.isCancelled {
                // 打てるようになるまで待つ
                var waited = 0
                while !(session.screen == .playing && session.canShoot), waited < 60 {
                    try? await Task.sleep(for: .milliseconds(100))
                    waited += 1
                }
                guard session.screen == .playing else { return }
                let s = shots[i % shots.count]
                // 少しずつ引いて、弧が増えていくところを見せる
                for k in 1...5 {
                    session.setPull(dx: s.0 * Double(k) / 5, dy: s.1 * Double(k) / 5)
                    try? await Task.sleep(for: .milliseconds(70))
                }
                try? await Task.sleep(for: .milliseconds(250))
                session.releasePull()
                i += 1
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}
#endif
