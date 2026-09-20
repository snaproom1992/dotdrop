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

    /// ここが true を返した瞬間に時間を止める。玉が増えきった1枚を撮るために使う
    @MainActor static var freezeWhen: ((GameSession) -> Bool)?
    @MainActor private static var frozen = false

    /// `GameSession.tickFrame` から毎フレーム呼ぶ。止めたあとはずっと止めたまま
    @MainActor
    static func freeze(_ session: GameSession) -> Bool {
        guard let test = freezeWhen else { return false }
        if frozen { return true }
        if test(session) { frozen = true }
        return frozen
    }

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

        case "demo", "split":
            // 動画用。**自分で打ち続ける。**simctl から指で触ることはできないので、
            // アプリ側で打つしかない。
            //
            // 台と打ち方は当てずっぽうではなく、`ios/tools/find-demo-shots.js` で
            // 総当たりして選んだもの。**実機と同じ寸法・同じ釘の間隔で探すこと**（下の注意）。
            // 種18・ステージ1（千鳥）の 55度・強さ3 が図抜けていて、
            //   ふつう      … 1回78点（中央値）・玉9個・100点超え42%
            //   フィーバー中 … 1回186点（中央値）・玉9個・100点超え67%
            session.startFreePlay()
            session.engine.boardSeed = 18
            session.engine.setLayout(0, animate: false)
            // 1回目でフィーバーに入るところまで溜めておく。黄色い画面と2倍の点が
            // 見せ場なので、28秒の中に必ず入れたい（120で突入、1回で60〜80たまる）
            // 動画は1回目でフィーバーに入るところまで溜めておく（120で突入、1回で78たまる）。
            // 静止画のほうは溜めない。フィーバーの黄色い画面は fever.png で見せているので、
            // ここはこげ茶のまま ■ ● ▲ の色が出ているほうがよい
            session.gauge = name == "split" ? 0 : 105
            if name == "split" {
                // ▲で増えたところで時間を止めて、その1枚を撮る。
                // **飛んでいる玉だけ数える。**`balls` には落ちきった玉も残っているので、
                // そのまま数えると3つしか飛んでいないのに6と出て、早く止まりすぎた
                session.money = 9; session.moneyShown = 9
                session.score = 1240; session.scoreShown = 1240
                session.engine.stage = 3
                session.boardShots = 2
                freezeWhen = { s in s.engine.balls.filter { $0.state == .fly }.count >= 5 }
            }
            playByItself(session)

        default:
            break
        }
    }

    /// 決め打ちの並びで打ち続ける。引く→ためる→はなす、を繰り返す
    @MainActor
    private static func playByItself(_ session: GameSession) {
        // (横に引く量, 下に引く量)。下に引くほど強い（上限130）。
        // 種12の台で総当たりして、▲に当たって玉がいちばん増えるものだけを残した。
        //
        // **探すときは実機と同じ台で回すこと。**2つ踏んだ。
        //   1. 本家の台は高さ700・発射140 だが、アプリは HUD のぶん発射が161.5まで
        //      下がり、画面も縦に長い（754）。釘の行数も位置も変わる
        //   2. 読み込む index.html を間違えると、釘の間隔が古いまま（42／いまは47）になる
        // どちらも「中央値96点のはず」が実機では7点・玉1個、という外し方をした。
        //
        // 強さの段（1〜5）の境目ちょうどだと1つ上に転びかねないので、わずかに内側にしてある
        // 数字はどれもフィーバー中の中央値（動画の大半がフィーバー中になるため）
        let shots: [(Double, Double)] = [
            (44.5, 63.6),     // 55° 強さ3　　186点・玉9・100点超え67%
            (-50.9, 58.6),    // 131° 強さ3　124点・100点超え52%
            (44.5, 63.6),     // 55° 強さ3
            (-29.2, 126.3),   // 103° 強さ5　100点・100点超え50%
            (33.7, 98.0),     // 71° 強さ4　　88点
            (44.5, 63.6),     // 55° 強さ3
            (-46.7, 62.0),    // 127° 強さ3　 90点
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
