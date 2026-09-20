import SwiftUI
import UIKit
import DotDropEngine

/// フリープレイ進行。`@Observable` で、読んだプロパティだけがビューを更新する。
@Observable
@MainActor
final class GameSession {
    @ObservationIgnored let engine = Engine()

    var screen: Screen = .title
    var money = 12
    var score = 0
    /// HUD 表示用（リールっぽく少し遅れて追いつく）
    var moneyShown = 12
    var scoreShown = 0
    var moneyBump = false
    var scoreBump = false
    /// STAGE の数字のはね。持ち玉・スコアより大きく跳ねる（本家は1.4倍）
    var stageBump = false
    var boardShots = 0
    var gauge = 0
    var feverLeft = 0
    var busy = false
    var firstShot = true
    /// 帯が出ている間 FEVER 行を消す（Web の body.banner-up）
    var bannerUp = false
    /// ドラッグ中に毎フレーム変わる。ビュー購読の対象にしない
    @ObservationIgnored var level = 0
    @ObservationIgnored var pullX = 0.0
    @ObservationIgnored var pullY = 0.0
    var showResetSheet = false
    var gameBestShot = 0
    var personalBest = 0
    var beatBest = false
    /// 今回の打った回数。ランキングに残す
    var shots = 0
    /// 持ち玉の最高（この1ゲームの中で）
    @ObservationIgnored var peakMoney = 12
    /// 結果画面に出すもの
    var rank = -1
    var rankingTop: [DDStore.RankEntry] = []
    var currentEntry: DDStore.RankEntry?
    var records: [String: Int] = [:]
    /// この起動で更新した項目（「更新」の札を出す）
    var newRecordKeys: Set<String> = []
    var tutorialCleared: Set<String> = []
    var tutorialIndex: Int?
    var tutorialValue = 0
    var tutorialSucceeded = false
    var isPaused = false
    var reduceMotion = false
    @ObservationIgnored var backgroundMix = 0.0
    @ObservationIgnored var moneyFrame: CGRect = .zero
    @ObservationIgnored var scoreFrame: CGRect = .zero
    @ObservationIgnored private var tutorialHits: [PegKind: Int] = [:]
    @ObservationIgnored private var tutorialGain = 0
    @ObservationIgnored private var tutorialMult = 0
    @ObservationIgnored private var tutorialMaxBalls = 1
    @ObservationIgnored private var endQuietTime = 0.0
    @ObservationIgnored private var scheduled: [(remaining: Double, action: () -> Void)] = []
    @ObservationIgnored private var bannerQueue: [GameFx.Banner] = []

    /// 演出（購読しない。BoardCanvas の TimelineView が描く）
    @ObservationIgnored var floaters: [GameFx.Floater] = []
    @ObservationIgnored var flyers: [GameFx.Flyer] = []
    @ObservationIgnored var catches: [GameFx.CatchBeam] = []
    @ObservationIgnored var waves: [GameFx.Wave] = []
    @ObservationIgnored var banner: GameFx.Banner?
    @ObservationIgnored var milestoneFx: GameFx.Milestone?
    @ObservationIgnored var edge: GameFx.Edge?
    @ObservationIgnored var perfectFx: GameFx.PerfectFx?
    @ObservationIgnored var slotFlash: GameFx.SlotFlash?
    @ObservationIgnored var potShow: Double = 0
    @ObservationIgnored var potAlpha: Double = 0
    @ObservationIgnored var potPulse: Double = 0
    @ObservationIgnored var shotShow: Double = 0
    @ObservationIgnored var shotBallsMax: Int = 1
    @ObservationIgnored var hitStop: Double = 0
    @ObservationIgnored var shake: Double = 0
    @ObservationIgnored var slowPulse: Double = 0
    @ObservationIgnored var timeScale: Double = 1
    @ObservationIgnored var shotMilestone: Int = 0
    @ObservationIgnored var maxShown = false

    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var triBonus = false
    @ObservationIgnored private var bestAtStart = 0
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var displayDriver: DisplayDriver?
    @ObservationIgnored private var pendingGameOver = false
    @ObservationIgnored private var lastFit: BoardFit?
    @ObservationIgnored private var safeTop: CGFloat = 59
    @ObservationIgnored private var collectCombo = 0
    @ObservationIgnored private var lastCollect: CFTimeInterval = 0
    @ObservationIgnored private var lastScoreStep: CFTimeInterval = 0
    /// 引いている間に鳴らした段。同じ段で鳴りっぱなしにしない
    @ObservationIgnored private var lastStep = 0

    enum Screen { case title, playing, result, tutorialList, tutorialResult }
    var tutorial: TutorialStep? { tutorialIndex.map { TutorialStep.all[$0] } }

    init() {
        loadTutorialProgress()
        personalBest = storedBest()
    }

    var fever: Bool { engine.fever }
    var canShoot: Bool {
        screen == .playing && !isPaused && !busy && !pendingGameOver && !showResetSheet && money >= engine.config.cost && engine.balls.isEmpty
    }

    var feverProgress: CGFloat {
        if engine.fever { return CGFloat(feverLeft) / CGFloat(max(1, engine.config.feverShots)) }
        return CGFloat(min(1, Double(gauge) / Double(max(1, engine.config.feverAt))))
    }

    func applyFit(_ fit: BoardFit, safeTop: CGFloat? = nil) {
        lastFit = fit
        if let safeTop { self.safeTop = safeTop }
        let lh = fit.logicalHeight
        // 発射位置は固定値にしない。**本家の 140 は本家の HUD の高さを前提にした数字**で、
        // ネイティブは STAGE の列が約6pt 高く、待機中のリングも約4pt 太いので、
        // そのまま持ってくると丸とリングが食い合う。HUD の下端から決める。
        //   HUD の下端 ＝ safe-area ＋ ヘッダーの余白38 ＋ STAGE の列46（実測）
        //   狙いの点線の弧は玉の中心から上へ34。そこに8の余裕を足した高さまで玉を下げる
        // ノッチのない端末では 140 に収まり、本家と同じ位置になる
        let hudBottom = Double(self.safeTop) + 38 + 46
        let launchY = max(Engine.baseLaunchY, hudBottom / Double(fit.scale) + 34 + 8)
        // 玉と釘の間隔は本家と同じ60を保つ
        let fieldTop = launchY + 60
        let heightChanged = abs(engine.logicalHeight - lh) > 0.5
        let launchChanged = abs(engine.launchY - launchY) > 0.5
        let fieldChanged = abs(engine.fieldTop - fieldTop) > 0.5
        guard heightChanged || launchChanged || fieldChanged else { return }
        engine.logicalHeight = lh
        engine.launchY = launchY
        engine.fieldTop = fieldTop
        if screen == .playing, engine.balls.isEmpty {
            engine.setLayout(engine.layout, animate: false)
        }
    }

    func openTitle() {
        scheduled.removeAll()
        GameAudio.shared.stopEffects()
        GameHaptics.cancel()
        stopDisplayLoop()
        screen = .title
        busy = false
        showResetSheet = false
        banner = nil
        bannerUp = false
        clearFx()
        loadTutorialProgress()
        personalBest = storedBest()
        tutorialIndex = nil
        isPaused = false
    }

    func startFreePlay() {
        tutorialIndex = nil
        startGame()
    }

    func openTutorialList() {
        openTitle()
        screen = .tutorialList
    }

    func startTutorial(_ index: Int) {
        guard TutorialStep.all.indices.contains(index) else { return }
        tutorialIndex = index
        startGame()
        if let tutorial { schedule(after: 0.25) { [weak self] in
            self?.showBanner("\(index + 1)", tutorial.hint, DD.paper)
        } }
    }

    func restart() {
        if let index = tutorialIndex { startTutorial(index) } else { startFreePlay() }
    }

    private func startGame() {
        scheduled.removeAll()
        GameAudio.shared.stopEffects()
        GameHaptics.cancel()
        isPaused = false
        tutorialValue = 0; tutorialSucceeded = false
        tutorialHits = [:]; tutorialGain = 0; tutorialMult = 0; tutorialMaxBalls = 1
        endQuietTime = 0
        moneyFrame = .zero; scoreFrame = .zero
        GameAudio.shared.unlock()
        GameHaptics.prepare()
        GameAudio.shared.playStart()
        GameHaptics.buzz(.medium, gap: 0)
        engine.applyConf(tutorial?.config ?? .freePlay)
        engine.boardSeed = tutorial?.seed
        engine.stage = 0
        engine.fever = false
        engine.balls = []
        engine.pot = 0
        engine.conveyor = 0
        engine.time = 0
        if let fit = lastFit {
            applyFit(fit, safeTop: safeTop)
        }
        engine.setLayout(tutorial?.layout ?? 0, animate: false)
        money = engine.config.startBalls
        moneyShown = money
        score = 0
        scoreShown = 0
        boardShots = 0
        gauge = 0
        feverLeft = 0
        busy = false
        firstShot = true
        level = 0
        pullX = 0
        pullY = 0
        banner = nil
        bannerUp = false
        triBonus = false
        gameBestShot = 0
        beatBest = false
        shots = 0
        peakMoney = money
        newRecordKeys = []
        rank = -1
        currentEntry = nil
        pendingGameOver = false
        clearFx()
        moneyBump = false; scoreBump = false; stageBump = false
        lastStep = 0; collectCombo = 0; lastCollect = 0; lastScoreStep = 0
        bestAtStart = storedBest()
        personalBest = bestAtStart
        screen = .playing
        wireHooks()
        startDisplayLoop()
    }

    func pause() {
        guard screen == .playing else { return }
        isPaused = true
        pullX = 0; pullY = 0; level = 0; lastStep = 0
        stopDisplayLoop()
        GameAudio.shared.suspend()
        GameHaptics.cancel()
    }

    func resume() {
        guard screen == .playing else { return }
        isPaused = false
        GameAudio.shared.unlock()
        startDisplayLoop()
    }

    /// 帯が使える幅（論理座標）。画面の幅 ÷ 拡大率
    private var bannerScreenWidth: Double {
        guard let f = lastFit, f.scale > 0 else { return Engine.logicalWidth }
        return Engine.logicalWidth + 2 * Double(f.ox / f.scale)
    }

    private func schedule(after delay: Double, _ action: @escaping () -> Void) {
        scheduled.append((delay, action))
    }

    func setPull(dx: Double, dy: Double) {
        let mag = hypot(dx, max(0, dy))
        let maxPull = Engine.maxPull
        let levels = Engine.levels
        level = mag < 14 ? 0 : min(levels, Int(ceil(mag / (maxPull / Double(levels)))))
        // 段が変わるたびに、音と振動で強さを返す。**これが無いと引いている間ずっと無音になる**
        //
        // **上がるときだけでなく、下がるときも鳴らす。**片方だけだと、
        // 引きすぎて戻したときに何も返ってこず、いま何段目か分からなくなる。
        // 音程はペンタトニックの段をそのまま使う（釘の音と同じ言語）。
        // 下がるときは1つ下の段（`level * 2`）にして、上がるときの音と混ざらないようにする
        if level != lastStep {
            let up = level > lastStep
            let rung = up ? level * 2 + 1 : max(1, level * 2)
            GameAudio.shared.voice(
                freq: GameAudio.shared.note(rung, fever: engine.fever),
                dur: 0.08,
                gain: up ? 0.08 : 0.06,
                // いちばん上まで引いたときだけ矩形波。戻すときは鳴らし分けない
                wave: (up && level == levels) ? .square : .triangle
            )
            GameHaptics.buzz(up && level == levels ? .heavy : .light, gap: 0)
        }
        lastStep = level
        let len = hypot(dx, dy)
        guard len > 0.0001 else { pullX = 0; pullY = 0; return }
        let p = Double(level) / Double(levels) * maxPull
        pullX = dx / len * p
        pullY = dy / len * p
    }

    func releasePull() {
        defer { pullX = 0; pullY = 0; level = 0; lastStep = 0 }
        guard canShoot, level > 0 else { return }
        shots += 1
        let (vx, vy) = engine.launchVelocity(pullX: pullX, pullY: pullY, exact: false)
        engine.launch(vx: vx, vy: vy)
        money -= engine.config.cost
        bumpMoney()
        busy = true
        firstShot = false
        triBonus = false
        shotBallsMax = 1
        shotShow = 0
        potShow = 0
        shotMilestone = 0
        maxShown = false
        lastDate = nil
        wireHooks()
        GameAudio.shared.playShoot()
        GameHaptics.buzz(.light, gap: 0)
    }

    private func wireHooks() {
        engine.hooks.hit = { [weak self] peg, _, n, force, kind, pts in
            guard let self else { return }
            self.tutorialHits[kind, default: 0] += 1
            self.waves.append(.init(x: peg.x, y: peg.y, big: kind != .dot))
            if self.waves.count > 40 { self.waves.removeFirst(self.waves.count - 40) }
            self.potPulse = 1
            if !self.engine.fever { self.gauge += pts }
            if pts > 1 {
                // ● 青だけは、そのままの青だと背景に沈むので明るい青にする（本家と同じ）
                let col: Color = kind == .blue
                    ? Color(hex: 0x7FA2EC)
                    : GameFx.shapeColor(kind, fever: self.engine.fever)
                self.floaters.append(.init(x: peg.x, y: peg.y - 16, text: "+\(pts)", color: col, life: 0.9, big: false))
            }
            switch kind {
            case .dot:
                GameHaptics.buzz(.light)
            case .square:
                self.hitStop = max(self.hitStop, 0.05)
                self.shake = max(self.shake, 0.2)
                GameHaptics.hit(.square)
            case .blue:
                GameHaptics.hit(.blue)
            case .tri:
                let count = self.engine.balls.count
                self.hitStop = max(self.hitStop, count >= 9 ? 0.1 : 0.06)
                self.shake = max(self.shake, min(0.6, 0.2 + Double(count) * 0.02))
                GameHaptics.hit(.tri)
                if count >= 9 { self.slowPulse = 0.35 }
                if count >= self.engine.config.maxBalls, !self.maxShown {
                    self.maxShown = true
                    self.showBanner("×\(self.engine.config.maxBalls)", String(localized: "玉が最大まで増えました"), DD.mustard)
                    GameHaptics.pattern(5, intervalMs: 60)
                }
                if !self.triBonus {
                    let tris = self.engine.pegs.filter { $0.kind == .tri }
                    if tris.count == 3, tris.allSatisfy(\.triHit) {
                        self.triBonus = true
                        self.showBanner("▲▲▲", String(localized: "3つとも当てて +3玉"), DD.mustard)
                        let mid = self.engine.field()
                        self.sendBalls(3, x: Engine.logicalWidth / 2, y: (mid.top + mid.bottom) / 2,
                                       color: GameFx.shapeColor(.tri, fever: self.engine.fever))
                        GameHaptics.pattern(4, intervalMs: 70)
                    }
                }
            }
            if n % 10 == 0 {
                self.hitStop = max(self.hitStop, 0.05)
                self.shake = max(self.shake, 0.15)
            }
            GameAudio.shared.playHit(kind: kind, hitCount: n, ballCount: self.engine.balls.count, force: force, fever: self.engine.fever)
            self.checkMilestone()
        }
        engine.hooks.shotEnd = { [weak self] _ in
            guard let self else { return }
            self.gameBestShot = max(self.gameBestShot, self.engine.shotScore)
            let newShot = self.noteRecord("shotScore", self.engine.shotScore)
            let newBalls = self.noteRecord("shotBalls", self.shotBallsMax)
            self.noteRecord("shotHits", self.engine.hitCount)
            self.busy = false
            self.feverStep()
            if self.tutorial != nil {
                self.updateTutorial()
                self.engine.pickGold()
            } else {
                if newShot && self.shots > 1 {
                    let points = self.engine.shotScore
                    self.schedule(after: 0.5) { [weak self] in self?.showBanner("BEST", String(localized: "1回の最高スコアを更新 \(points)"), DD.paper) }
                } else if newBalls && self.shots > 1 {
                    self.schedule(after: 0.5) { [weak self] in self?.showBanner("BEST", String(localized: "1回で増えた玉の最多記録"), DD.mustard) }
                }
                self.afterShot()
            }
            if self.money < self.engine.config.cost || self.tutorialSucceeded || (self.tutorial != nil && self.shots >= 25) {
                self.pendingGameOver = true
                self.endQuietTime = 0
            }
        }
        engine.hooks.perfect = { [weak self] bonus in
            guard let self else { return }
            self.perfectFx = .init()
            self.hitStop = max(self.hitStop, 0.45)
            self.shake = max(self.shake, 1.1)
            self.showBanner("PERFECT", String(localized: "ドットをすべて赤くした +\(bonus)"), DD.red)
            self.edge = .init(color: nil, width: 44)
            // The engine adds the bonus to shotScore; the UI ledger must receive it exactly once too.
            let f = self.engine.field()
            self.sendScore(bonus, x: Engine.logicalWidth / 2, y: (f.top + f.bottom) / 2, color: DD.red)
            GameAudio.shared.playPerfect()
            GameHaptics.pattern(8, intervalMs: 95)
        }
        engine.hooks.land = { [weak self] ball, v, _ in
            self?.onLand(ball: ball, v: v)
        }
        engine.hooks.release = { [weak self] peg, _ in
            peg.pulse = 1
            GameAudio.shared.voice(freq: GameAudio.shared.note(12, fever: self?.engine.fever ?? false), dur: 0.15, gain: 0.08)
            GameHaptics.buzz(.light, gap: 0)
        }
    }

    private func checkMilestone() {
        let value = max(engine.pot, engine.shotScore)
        let reached = min(10, value / 100)
        guard reached > shotMilestone else { return }
        shotMilestone = reached
        potPulse = 1.5
        let color = GameFx.milestoneColor(reached)
        milestoneFx = .init(level: reached, color: color)
        edge = .init(
            color: color,
            width: 14 + Double(reached) * 2 + (GameFx.isCycle(reached) ? 8 : 0)
        )
        shake = max(shake, 0.2 + Double(reached) * 0.04)
        hitStop = max(hitStop, 0.06 + Double(reached) * 0.01)
        GameAudio.shared.playMilestone(level: reached)
        GameHaptics.pattern(min(5, 1 + reached / 2), intervalMs: 70)
    }

    private func onLand(ball: Ball, v: Int) {
        let top = engine.slotTop()
        let m = ball.mult
        let gain = ball.gain
        let fever = engine.fever
        if ball.pts > 0 { tutorialMult = max(tutorialMult, m) }
        tutorialGain += max(0, v)
        catches.append(.init(slot: ball.slot, m: m))

        if m > 0, ball.pts > 0 {
            let col = GameFx.multColor(m, fever: fever)
            floaters.append(.init(
                x: ball.x, y: top - 22,
                text: "\(ball.pts)×\(m)",
                color: col, life: 0.5, big: true
            ))
            sendScore(gain, x: ball.x, y: top - 22, color: col)
            noteRecord("ballGain", gain)
            GameAudio.shared.voice(freq: GameAudio.shared.note(4 + m, fever: fever), dur: 0.18, gain: 0.1, wave: .square)
            GameAudio.shared.noise(dur: 0.04, gain: 0.12, freq: 3000)
            hitStop = max(hitStop, m >= 5 ? 0.14 : 0.05)
            if m >= 5 {
                shake = max(shake, 0.45)
                edge = .init(color: DD.red)
                GameHaptics.pattern(3, intervalMs: 60)
            } else {
                GameHaptics.buzz(.medium, gap: 0)
            }
        } else {
            floaters.append(.init(
                x: ball.x, y: top - 22,
                text: "×0",
                color: DD.fg(fever: fever).opacity(0.45),
                life: 0.7, big: true
            ))
            // ×0 のがっかり。低く丸い音
            GameAudio.shared.voice(freq: 150, dur: 0.14, gain: 0.08, wave: .sine)
            GameAudio.shared.noise(dur: 0.05, gain: 0.06, freq: 400)
        }

        if v > 0 {
            floaters.append(.init(
                x: ball.x, y: top - 50,
                text: String(localized: "+\(v)玉"),
                color: DD.fg(fever: fever),
                life: 0.9, big: false
            ))
            sendBalls(v, x: ball.x, y: top, color: DD.ball(fever: fever))
        } else if v < 0 {
            let lose = min(-v, money)
            if lose > 0 {
                money -= lose
                bumpMoney()
                let from = moneyTarget()
                for i in 0..<lose {
                    flyers.append(.init(
                        kind: .minus,
                        x0: from.x, y0: from.y,
                        t: -Double(i) * 0.08,
                        color: DD.red,
                        arc: 0,
                        tx: ball.x, ty: top + 20
                    ))
                }
            }
            floaters.append(.init(
                x: ball.x, y: top - 50,
                text: "−\(-v)",
                color: DD.red, life: 1, big: true
            ))
            if -v >= 3 {
                edge = .init(color: DD.red)
                shake = max(shake, 0.45)
            }
            shake = max(shake, 0.25)
            // 玉が減ったときの「ブー」。**ノコギリ波でないと、ただの低い音になって残念さが出ない**
            GameAudio.shared.voice(freq: 110, dur: 0.35, gain: 0.12, wave: .sawtooth)
            GameAudio.shared.noise(dur: 0.15, gain: 0.12, freq: 250)
            GameHaptics.pattern(2, intervalMs: 90)
        }
        checkMilestone()
    }

    private func sendBalls(_ n: Int, x: Double, y: Double, color: Color) {
        for i in 0..<n {
            flyers.append(.init(
                kind: .ball,
                x0: x, y0: y,
                t: -Double(i) * 0.09,
                color: color,
                arc: (Double.random(in: 0...1) - 0.5) * 60
            ))
        }
    }

    private func sendScore(_ value: Int, x: Double, y: Double, color: Color) {
        guard value > 0 else { return }
        flyers.append(.init(
            kind: .score,
            x0: x, y0: y,
            t: -0.35,
            color: color,
            arc: (Double.random(in: 0...1) - 0.5) * 40,
            value: value
        ))
    }

    private func moneyTarget() -> (x: Double, y: Double) {
        guard let fit = lastFit else { return (40, 90) }
        let p = moneyTargetScreen()
        return (Double((p.x - fit.ox) / fit.scale), Double(p.y / fit.scale))
    }

    func moneyTargetScreen() -> CGPoint {
        if moneyFrame.width > 0 { return CGPoint(x: max(moneyFrame.midX, moneyFrame.maxX - 16), y: moneyFrame.midY) }
        guard lastFit != nil else { return CGPoint(x: 56, y: 120) }
        return CGPoint(x: CGFloat(20 + 36), y: safeTop + 38 + 23)
    }
    func scoreTargetScreen() -> CGPoint {
        if scoreFrame.width > 0 { return CGPoint(x: min(scoreFrame.midX, scoreFrame.minX + 16), y: scoreFrame.midY) }
        guard let fit = lastFit else { return CGPoint(x: 320, y: 120) }
        let width = fit.ox * 2 + EngineLogical.w * fit.scale
        return CGPoint(x: width - 56, y: safeTop + 38 + 23)
    }

    private func feverStep() {
        if engine.fever {
            feverLeft -= 1
            if feverLeft <= 0 {
                engine.fever = false
                gauge = 0
            }
        } else if gauge >= engine.config.feverAt {
            engine.fever = true
            feverLeft = engine.config.feverShots
            showBanner("FEVER", String(localized: "\(engine.config.feverShots)回、ポイント2倍・玉が減らない"), DD.red)
            GameAudio.shared.playFever(fever: true)
            GameHaptics.pattern(4, intervalMs: 80)
        }
    }

    private func afterShot() {
        boardShots += 1
        if boardShots >= engine.config.shotsPerBoard {
            boardShots = 0
            let before = engine.stageB()
            var next: Int
            repeat { next = Int.random(in: 0..<Engine.layouts) } while next == engine.layout
            engine.setLayout(next, animate: true)
            engine.stage += 1
            let after = engine.stageB()
            let changed = zip(before, after).enumerated().compactMap { i, pair in
                pair.0 != pair.1 ? i : nil
            }
            if !changed.isEmpty {
                slotFlash = .init(slots: changed)
            }
            noteRecord("stage", engine.stage + 1)
            stageBump = true
            schedule(after: 0.2) { [weak self] in
                self?.stageBump = false
            }
            let stage = engine.stage + 1
            schedule(after: 0.9) { [weak self] in
                self?.showBanner("STAGE \(stage)", String(localized: "ステージが上がりました"), DD.paper)
            }
        } else {
            engine.pickGold()
        }
    }

    func finishGame() {
        stopDisplayLoop()
        pendingGameOver = false
        if tutorial != nil {
            screen = .tutorialResult
            busy = false; bannerUp = false
            scheduled.removeAll()
            return
        }
        noteRecord("gameScore", score)
        noteRecord("peakMoney", peakMoney)
        let entry = DDStore.RankEntry(score: score, stage: engine.stage + 1, shots: shots, date: Date())
        rank = DDStore.addRanking(entry)
        currentEntry = entry
        rankingTop = DDStore.ranking()
        records = DDStore.records()
        saveBest(score)
        personalBest = storedBest()
        screen = .result
        busy = false
        bannerUp = false
    }

    func showBanner(_ word: String, _ sub: String, _ color: Color) {
        var next = GameFx.Banner(word: word, sub: sub, color: color)
        next.fit(screenWidth: bannerScreenWidth)
        if banner != nil {
            if !bannerQueue.contains(where: { $0.word == word }) { bannerQueue.append(next) }
            return
        }
        banner = next
        bannerUp = true
        edge = .init(color: color)
    }

    /// 記録を更新したら覚えておく。結果画面で「更新」の札を出すため
    @discardableResult
    private func noteRecord(_ key: String, _ value: Int) -> Bool {
        guard tutorial == nil else { return false }
        let previous = DDStore.records()[key] ?? 0
        if value > previous {
            DDStore.bump(key, value)
            newRecordKeys.insert(key)
        }
        return previous > 0 && value > previous
    }

    private func updateTutorial() {
        guard let step = tutorial else { return }
        tutorialMaxBalls = max(tutorialMaxBalls, shotBallsMax)
        switch step.goal {
        case .shots: tutorialValue = shots
        case .multiplier: tutorialValue = tutorialMult
        case .gain: tutorialValue = tutorialGain
        case .hit(let kind): tutorialValue = tutorialHits[kind] ?? 0
        case .balls: tutorialValue = tutorialMaxBalls
        case .shotScore: tutorialValue = gameBestShot
        case .fever: tutorialValue = engine.fever ? 1 : 0
        }
        if tutorialValue >= step.target && !tutorialSucceeded {
            tutorialSucceeded = true
            tutorialCleared.insert(step.id)
            UserDefaults.standard.set(Array(tutorialCleared).sorted(), forKey: "dotdrop-tutorial")
            showBanner("CLEAR", "", DD.red)
            GameAudio.shared.playNewRecord(fever: engine.fever)
            GameHaptics.pattern(3, intervalMs: 80)
        }
    }

    private func bumpMoney() {
        moneyBump = true
        schedule(after: 0.12) { [weak self] in
            self?.moneyBump = false
        }
    }

    private func bumpScore() {
        scoreBump = true
        schedule(after: 0.12) { [weak self] in
            self?.scoreBump = false
        }
    }

    private func clearFx() {
        floaters = []
        flyers = []
        catches = []
        waves = []
        banner = nil
        bannerQueue.removeAll()
        bannerUp = false
        milestoneFx = nil
        edge = nil
        perfectFx = nil
        slotFlash = nil
        potShow = 0
        potAlpha = 0
        potPulse = 0
        shotShow = 0
        shotBallsMax = 1
        hitStop = 0
        shake = 0
        slowPulse = 0
        timeScale = 1
        shotMilestone = 0
        maxShown = false
        backgroundMix = 0
    }

    private func startDisplayLoop() {
        stopDisplayLoop()
        lastDate = Date()
        let driver = DisplayDriver(session: self)
        let link = CADisplayLink(target: driver, selector: #selector(DisplayDriver.step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayDriver = driver
        displayLink = link
    }

    private func stopDisplayLoop() {
        displayLink?.invalidate()
        displayLink = nil
        displayDriver = nil
        lastDate = nil
    }

    func tickFrame(now: Date) {
        let real: Double
        // 上限は本家と同じ 0.05。1/30 にすると、30fps を割ったときに
        // 時間そのものが実時間より遅れて、待機中のアニメまでゆっくりになる
        if let last = lastDate { real = min(now.timeIntervalSince(last), 0.05) }
        else { real = 0 }
        lastDate = now
        guard !isPaused, !showResetSheet, screen == .playing else { return }
        guard real > 0 else { return }
        #if DEBUG
        // 撮影のときだけ、決めた瞬間で時間を止める（製品のビルドには入らない）
        if ScreenshotMode.freeze(self) { return }
        #endif
        backgroundMix += ((engine.fever ? 1 : 0) - backgroundMix) * min(1, real * 5)
        let jobs = scheduled
        scheduled.removeAll()
        for job in jobs {
            if job.remaining <= real { job.action() }
            else { scheduled.append((job.remaining - real, job.action)) }
        }

        // スロー（×5 直前・分裂が多いとき）
        var slow = false
        if busy {
            let top = engine.slotTop()
            for b in engine.balls where b.state == .fly && b.vy > 0 {
                let gap = top - b.y
                if gap > 0, gap < 110 {
                    let t = gap / b.vy
                    let slot = engine.slotAt(b.x + b.vx * t, t: t)
                    if engine.slotInfo(slot).m >= 5 { slow = true; break }
                }
            }
            if shotBallsMax > 4 { slow = false }
        }
        if slowPulse > 0 {
            slowPulse -= real
            slow = true
        }
        timeScale += ((slow ? 0.3 : 1) - timeScale) * min(1, real * 12)

        // hitStop 中は物理を止める
        if hitStop > 0 {
            hitStop -= real
        } else if busy {
            var left = real * timeScale
            let step = Engine.physicsSubstep
            while left > 0 {
                let d = min(step, left)
                engine.stepPhysics(dt: d)
                left -= d
                if !busy { break }
            }
            for b in engine.balls where b.state == .fly {
                b.trail.append((b.x, b.y))
                if b.trail.count > 8 { b.trail.removeFirst() }
            }
            shotBallsMax = max(shotBallsMax, engine.balls.count)
            checkMilestone()
        }

        for p in engine.pegs {
            p.pulse = max(0, p.pulse - real * 5)
            if engine.balls.isEmpty { p.lit = max(0, p.lit - real * 1.2) }
            if p.m < 1 {
                p.m = min(1, p.m + real * 1.4)
                let k = GameFx.ease(p.m)
                p.x = p.fx + (p.tx - p.fx) * k
                p.y = p.fy + (p.ty - p.fy) * k
            }
        }
        if engine.balls.isEmpty && !busy {
            engine.time += real
            engine.conveyor += Engine.conveyorSpeed * real
        }

        // FX timers
        for i in floaters.indices { floaters[i].t += real }
        floaters.removeAll { $0.t >= $0.life }
        for i in catches.indices { catches[i].t += real }
        catches.removeAll { $0.t >= 1 }
        for i in waves.indices { waves[i].t += real }
        waves.removeAll { $0.t >= 0.7 }

        if var b = banner {
            b.t += real
            if b.t > 1.5 {
                banner = bannerQueue.isEmpty ? nil : bannerQueue.removeFirst()
                bannerUp = banner != nil
            } else {
                banner = b
            }
        }
        if var m = milestoneFx {
            m.t += real
            milestoneFx = m.t > 1.2 ? nil : m
        }
        if var e = edge {
            e.t += real
            edge = e.t >= 0.9 ? nil : e
        }
        if var p = perfectFx {
            p.t += real
            perfectFx = p.t > 2.1 ? nil : p
        }
        if var sf = slotFlash {
            sf.t += real
            slotFlash = sf.t > 2 ? nil : sf
        }

        potShow += (Double(engine.pot) - potShow) * min(1, real * 18)
        potPulse = max(0, potPulse - real * 6)
        let targetAlpha: Double = engine.balls.isEmpty ? 0 : 1
        potAlpha += (targetAlpha - potAlpha) * min(1, real * 3)
        if engine.shotScore > 0 {
            shotShow += (Double(engine.shotScore) - shotShow) * min(1, real * 8)
        }
        shake = max(0, shake - real * 1.6)

        // 持ち玉はすぐ追いつく／スコアはコロコロ
        if moneyShown != money {
            moneyShown = money
        }
        let nowT = CACurrentMediaTime()
        if scoreShown < score, nowT - lastScoreStep > 0.06 {
            lastScoreStep = nowT
            let step = max(1, Int(ceil(Double(score - scoreShown) * 0.18)))
            scoreShown = min(score, scoreShown + step)
            if Double.random(in: 0...1) < 0.5 {
                GameAudio.shared.voice(freq: 2400, dur: 0.02, gain: 0.025, wave: .sine)
            }
        }

        // flyers
        for i in flyers.indices {
            flyers[i].t += real
            if flyers[i].t >= 0.55, !flyers[i].done {
                flyers[i].done = true
                switch flyers[i].kind {
                case .minus:
                    GameAudio.shared.noise(dur: 0.05, gain: 0.08, freq: 300)
                case .ball:
                    money += 1
                    peakMoney = max(peakMoney, money)
                    bumpMoney()
                    let nowC = CACurrentMediaTime()
                    collectCombo = nowC - lastCollect < 0.25 ? collectCombo + 1 : 0
                    lastCollect = nowC
                    GameAudio.shared.voice(
                        freq: GameAudio.shared.note(6 + min(collectCombo, 8), fever: engine.fever) * 2,
                        dur: 0.09, gain: 0.09
                    )
                    GameHaptics.buzz(.light, gap: 0)
                case .score:
                    score += flyers[i].value
                    bumpScore()
                    if tutorial == nil, !beatBest, bestAtStart > 0, score > bestAtStart {
                        beatBest = true
                        showBanner("NEW RECORD", String(localized: "自己ベスト\(bestAtStart)を超えた"), DD.red)
                        GameAudio.shared.playNewRecord(fever: engine.fever)
                        GameHaptics.pattern(3, intervalMs: 80)
                    }
                    GameAudio.shared.voice(
                        freq: GameAudio.shared.note(10, fever: engine.fever) * 2,
                        dur: 0.06, gain: 0.06, wave: .sine
                    )
                    GameHaptics.buzz(.light, gap: 0)
                }
            }
        }
        flyers.removeAll { $0.done }

        if pendingGameOver {
            let tutorialOver = tutorial != nil && (tutorialSucceeded || shots >= 25)
            if money >= engine.config.cost && !tutorialOver {
                pendingGameOver = false
            } else if flyers.isEmpty, engine.balls.isEmpty {
                endQuietTime += real
                if endQuietTime >= 0.9, scoreShown == score, banner == nil, perfectFx == nil, milestoneFx == nil {
                    finishGame()
                }
            }
        }
    }

    // MARK: - Storage

    private func storedBest() -> Int {
        max(UserDefaults.standard.integer(forKey: "dotdrop-best-game"),
            max(DDStore.records()["gameScore"] ?? 0, DDStore.ranking().map(\.score).max() ?? 0))
    }
    private func saveBest(_ s: Int) {
        let k = "dotdrop-best-game"
        if s > UserDefaults.standard.integer(forKey: k) {
            UserDefaults.standard.set(s, forKey: k)
        }
    }
    private func loadTutorialProgress() {
        if let arr = UserDefaults.standard.array(forKey: "dotdrop-tutorial") as? [String] {
            tutorialCleared = Set(arr)
        }
    }
}

/// CADisplayLink retains its target. Keep the session weak so abandoning a window releases it.
@MainActor
private final class DisplayDriver: NSObject {
    weak var session: GameSession?
    init(session: GameSession) { self.session = session }
    @objc func step(_ link: CADisplayLink) {
        guard let session else { link.invalidate(); return }
        session.tickFrame(now: Date())
    }
}
