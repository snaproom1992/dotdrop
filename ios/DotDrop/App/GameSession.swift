import SwiftUI
import DotDropEngine

/// フリープレイ進行。`@Observable` で、読んだプロパティだけがビューを更新する。
@Observable
@MainActor
final class GameSession {
    @ObservationIgnored let engine = Engine()

    var screen: Screen = .title
    var money = 12
    var score = 0
    var boardShots = 0
    var gauge = 0
    var feverLeft = 0
    var busy = false
    var firstShot = true
    /// ドラッグ中に毎フレーム変わる。ビュー購読の対象にしない
    @ObservationIgnored var level = 0
    @ObservationIgnored var pullX = 0.0
    @ObservationIgnored var pullY = 0.0
    var banner: Banner?
    var showResetSheet = false
    var gameBestShot = 0
    var personalBest = 0
    var beatBest = false
    var tutorialCleared: Set<String> = []

    /// 演出（購読しない。BoardCanvas の TimelineView が描く）
    @ObservationIgnored var floaters: [GameFx.Floater] = []
    @ObservationIgnored var flyers: [GameFx.Flyer] = []
    @ObservationIgnored var catches: [GameFx.CatchBeam] = []
    /// 背景の大きな点数（Web の potShow / potAlpha / potPulse）
    @ObservationIgnored var potShow: Double = 0
    @ObservationIgnored var potAlpha: Double = 0
    @ObservationIgnored var potPulse: Double = 0
    @ObservationIgnored var shotShow: Double = 0
    @ObservationIgnored var shotBallsMax: Int = 1

    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var triBonus = false
    @ObservationIgnored private var bestAtStart = 0
    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var pendingGameOver = false
    @ObservationIgnored private var lastFit: BoardFit?
    @ObservationIgnored private var safeTop: CGFloat = 59
    @ObservationIgnored private var collectCombo = 0
    @ObservationIgnored private var lastCollect: CFTimeInterval = 0

    enum Screen { case title, playing, result }

    struct Banner {
        var word: String
        var sub: String
        var color: Color
        var born: Date
    }

    init() {
        loadTutorialProgress()
        personalBest = storedBest()
    }

    var fever: Bool { engine.fever }
    var canShoot: Bool {
        screen == .playing && !busy && !showResetSheet && money >= engine.config.cost && engine.balls.isEmpty
    }

    var feverProgress: CGFloat {
        if engine.fever { return CGFloat(feverLeft) / CGFloat(max(1, engine.config.feverShots)) }
        return CGFloat(min(1, Double(gauge) / Double(max(1, engine.config.feverAt))))
    }

    func applyFit(_ fit: BoardFit, safeTop: CGFloat? = nil) {
        lastFit = fit
        if let safeTop { self.safeTop = safeTop }
        let lh = fit.logicalHeight
        // 発射と釘上端は必ず同じだけ動かす（間隔 60 = 200-140）。
        // ノッチ分だけ下げて STAGE と被らないようにする。片方だけ動かすとパワー弧が釘に被る。
        let shift = fit.bannerY - 116 // = min(safeTop/scale, 26)
        let launchY = Engine.baseLaunchY + shift
        let fieldTop = 200 + shift
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
        stopDisplayLoop()
        screen = .title
        busy = false
        showResetSheet = false
        banner = nil
        clearFx()
        loadTutorialProgress()
        personalBest = storedBest()
    }

    func startFreePlay() {
        GameAudio.shared.unlock()
        GameHaptics.prepare()
        GameAudio.shared.playStart()
        GameHaptics.buzz(.medium, gap: 0)
        engine.applyConf(.freePlay)
        engine.boardSeed = nil
        engine.stage = 0
        engine.fever = false
        engine.balls = []
        engine.pot = 0
        engine.conveyor = 0
        engine.time = 0
        // 台を組む前に LH / 発射 / 釘上端を現在の画面に合わせる
        if let fit = lastFit {
            applyFit(fit, safeTop: safeTop)
        }
        engine.setLayout(0, animate: false)
        money = engine.config.startBalls
        score = 0
        boardShots = 0
        gauge = 0
        feverLeft = 0
        busy = false
        firstShot = true
        level = 0
        pullX = 0
        pullY = 0
        banner = nil
        triBonus = false
        gameBestShot = 0
        beatBest = false
        pendingGameOver = false
        clearFx()
        bestAtStart = storedBest()
        personalBest = bestAtStart
        screen = .playing
        wireHooks()
        startDisplayLoop()
    }

    func setPull(dx: Double, dy: Double) {
        let mag = hypot(dx, max(0, dy))
        let maxPull = Engine.maxPull
        let levels = Engine.levels
        level = mag < 14 ? 0 : min(levels, Int(ceil(mag / (maxPull / Double(levels)))))
        let len = hypot(dx, dy)
        guard len > 0.0001 else { pullX = 0; pullY = 0; return }
        let p = Double(level) / Double(levels) * maxPull
        pullX = dx / len * p
        pullY = dy / len * p
    }

    func releasePull() {
        defer { pullX = 0; pullY = 0; level = 0 }
        guard canShoot, level > 0 else { return }
        let (vx, vy) = engine.launchVelocity(pullX: pullX, pullY: pullY, exact: false)
        engine.launch(vx: vx, vy: vy)
        money -= engine.config.cost
        busy = true
        firstShot = false
        triBonus = false
        shotBallsMax = 1
        shotShow = 0
        potShow = 0
        lastDate = nil
        wireHooks()
        GameAudio.shared.playShoot()
        GameHaptics.buzz(.light, gap: 0)
    }

    private func wireHooks() {
        engine.hooks.hit = { [weak self] peg, _, n, _, kind, pts in
            guard let self else { return }
            self.potPulse = 1
            if !self.engine.fever { self.gauge += pts }
            if pts > 1 {
                let col: Color = kind == .blue ? Color(hex: 0x7FA2EC) : (kind == .square ? DD.red : DD.mustard)
                self.floaters.append(.init(x: peg.x, y: peg.y - 16, text: "+\(pts)", color: col, life: 0.9, big: false))
            }
            if !self.triBonus {
                let tris = self.engine.pegs.filter { $0.kind == .tri }
                if tris.count == self.engine.config.tris, tris.allSatisfy(\.triHit) {
                    self.triBonus = true
                    self.showBanner("▲▲▲", "3つとも当てて +3玉", DD.mustard)
                    let mid = self.engine.field()
                    self.sendBalls(3, x: Engine.logicalWidth / 2, y: (mid.top + mid.bottom) / 2, color: DD.mustard)
                    GameHaptics.pattern(4, intervalMs: 70)
                }
            }
            GameAudio.shared.playHit(kind: kind, hitCount: n, fever: self.engine.fever)
            switch kind {
            case .dot: GameHaptics.buzz(.light)
            case .square: GameHaptics.buzz(.heavy, gap: 0)
            case .blue: GameHaptics.buzz(.medium, gap: 0)
            case .tri: GameHaptics.pattern(2, intervalMs: 50)
            }
        }
        engine.hooks.shotEnd = { [weak self] _ in
            guard let self else { return }
            // スコア・戻る玉は flyer が届いてから足す（Web と同じ）
            self.gameBestShot = max(self.gameBestShot, self.engine.shotScore)
            self.busy = false
            self.feverStep()
            self.afterShot()
            if self.money < self.engine.config.cost {
                self.pendingGameOver = true
            }
        }
        engine.hooks.perfect = { [weak self] bonus in
            self?.showBanner("PERFECT", "ドットをすべて赤くした +\(bonus)", DD.red)
        }
        engine.hooks.land = { [weak self] ball, v, _ in
            self?.onLand(ball: ball, v: v)
        }
        engine.hooks.release = { peg, _ in
            peg.pulse = 1
            GameAudio.shared.voice(freq: GameAudio.shared.note(12, fever: false), dur: 0.15, gain: 0.08)
            GameHaptics.buzz(.light, gap: 0)
        }
    }

    private func onLand(ball: Ball, v: Int) {
        let top = engine.slotTop()
        let m = ball.mult
        let gain = ball.gain
        let fever = engine.fever
        catches.append(.init(slot: ball.slot, m: m))

        if m > 0, ball.pts > 0 {
            let col = GameFx.multColor(m, fever: fever)
            floaters.append(.init(
                x: ball.x, y: top - 22,
                text: "\(ball.pts)×\(m)",
                color: col, life: 0.5, big: true
            ))
            sendScore(gain, x: ball.x, y: top - 22, color: col)
            GameAudio.shared.voice(freq: GameAudio.shared.note(4 + m, fever: fever), dur: 0.18, gain: 0.1)
            GameAudio.shared.noise(dur: 0.04, gain: 0.12, freq: 3000)
            if m >= 5 {
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
            GameAudio.shared.voice(freq: 150, dur: 0.14, gain: 0.08)
            GameAudio.shared.noise(dur: 0.05, gain: 0.06, freq: 400)
        }

        if v > 0 {
            floaters.append(.init(
                x: ball.x, y: top - 50,
                text: "+\(v)玉",
                color: DD.fg(fever: fever),
                life: 0.9, big: false
            ))
            sendBalls(v, x: ball.x, y: top, color: DD.ball(fever: fever))
        } else if v < 0 {
            let lose = min(-v, money)
            if lose > 0 {
                money -= lose
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
            GameAudio.shared.voice(freq: 110, dur: 0.35, gain: 0.12)
            GameAudio.shared.noise(dur: 0.15, gain: 0.12, freq: 250)
            GameHaptics.pattern(2, intervalMs: 90)
        }
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
        let sx: CGFloat = 20 + 36
        let sy: CGFloat = safeTop + 38 + 23
        return (Double((sx - fit.ox) / fit.scale), Double(sy / fit.scale))
    }

    private func scoreTarget() -> (x: Double, y: Double) {
        guard let fit = lastFit else { return (320, 90) }
        let width = fit.ox * 2 + EngineLogical.w * fit.scale
        let sx: CGFloat = width - 56
        let sy: CGFloat = safeTop + 38 + 23
        return (Double((sx - fit.ox) / fit.scale), Double(sy / fit.scale))
    }

    /// 描画用：持ち玉・スコアの画面座標
    func moneyTargetScreen() -> CGPoint {
        guard lastFit != nil else { return CGPoint(x: 56, y: 120) }
        return CGPoint(x: CGFloat(20 + 36), y: safeTop + 38 + 23)
    }
    func scoreTargetScreen() -> CGPoint {
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
            showBanner("FEVER", "\(engine.config.feverShots)回、ポイント2倍・玉が減らない", DD.red)
        }
    }

    private func afterShot() {
        boardShots += 1
        if boardShots >= engine.config.shotsPerBoard {
            boardShots = 0
            var next: Int
            repeat { next = Int.random(in: 0..<Engine.layouts) } while next == engine.layout
            engine.setLayout(next, animate: true)
            engine.stage += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.showBanner("STAGE \( (self?.engine.stage ?? 0) + 1)", "ステージが上がりました", DD.paper)
            }
        } else {
            engine.pickGold()
        }
    }

    func finishGame() {
        stopDisplayLoop()
        pendingGameOver = false
        saveBest(score)
        personalBest = storedBest()
        screen = .result
        busy = false
    }

    func showBanner(_ word: String, _ sub: String, _ color: Color) {
        banner = Banner(word: word, sub: sub, color: color, born: Date())
    }

    private func clearFx() {
        floaters = []
        flyers = []
        catches = []
        potShow = 0
        potAlpha = 0
        potPulse = 0
        shotShow = 0
        shotBallsMax = 1
    }

    private func startDisplayLoop() {
        stopDisplayLoop()
        lastDate = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickFrame(now: Date())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayLoop() {
        displayTimer?.invalidate()
        displayTimer = nil
        lastDate = nil
    }

    func tickFrame(now: Date) {
        if let b = banner, now.timeIntervalSince(b.born) > 1.5 { banner = nil }

        let real: Double
        if let last = lastDate { real = min(now.timeIntervalSince(last), 1.0 / 30.0) }
        else { real = 0 }
        lastDate = now
        guard real > 0 else { return }

        for p in engine.pegs {
            p.pulse = max(0, p.pulse - real * 5)
            if engine.balls.isEmpty { p.lit = max(0, p.lit - real * 1.2) }
            if p.m < 1 {
                p.m = min(1, p.m + real * 1.4)
                let k = 1 - pow(1 - p.m, 3)
                p.x = p.fx + (p.tx - p.fx) * k
                p.y = p.fy + (p.ty - p.fy) * k
            }
        }
        if engine.balls.isEmpty && !busy {
            engine.time += real
            engine.conveyor += Engine.conveyorSpeed * real
        }
        if busy {
            var left = real
            let step = Engine.physicsSubstep
            while left > 0 {
                let d = min(step, left)
                engine.stepPhysics(dt: d)
                left -= d
                if !busy { break }
            }
            // 軌跡（Web は draw で積む。ここでは物理後に1回）
            for b in engine.balls where b.state == .fly {
                b.trail.append((b.x, b.y))
                if b.trail.count > 8 { b.trail.removeFirst() }
            }
        }

        // floaters / catches / pot
        for i in floaters.indices { floaters[i].t += real }
        floaters.removeAll { $0.t >= $0.life }
        for i in catches.indices { catches[i].t += real }
        catches.removeAll { $0.t >= 1 }
        potShow += (Double(engine.pot) - potShow) * min(1, real * 18)
        potPulse = max(0, potPulse - real * 6)
        let targetAlpha: Double = engine.balls.isEmpty ? 0 : 1
        potAlpha += (targetAlpha - potAlpha) * min(1, real * 3)
        if engine.shotScore > 0 {
            shotShow += (Double(engine.shotScore) - shotShow) * min(1, real * 8)
        }
        if busy {
            shotBallsMax = max(shotBallsMax, engine.balls.count)
        }

        // flyers（届いたら持ち玉・スコアを足す）
        for i in flyers.indices {
            flyers[i].t += real
            if flyers[i].t >= 0.55, !flyers[i].done {
                flyers[i].done = true
                switch flyers[i].kind {
                case .minus:
                    GameAudio.shared.noise(dur: 0.05, gain: 0.08, freq: 300)
                case .ball:
                    money += 1
                    let nowT = CACurrentMediaTime()
                    collectCombo = nowT - lastCollect < 0.25 ? collectCombo + 1 : 0
                    lastCollect = nowT
                    GameAudio.shared.voice(
                        freq: GameAudio.shared.note(6 + min(collectCombo, 8), fever: false) * 2,
                        dur: 0.09, gain: 0.09
                    )
                    GameHaptics.buzz(.light, gap: 0)
                case .score:
                    score += flyers[i].value
                    if !beatBest, bestAtStart > 0, score > bestAtStart {
                        beatBest = true
                        showBanner("NEW RECORD", "自己ベスト\(bestAtStart)を超えた", DD.red)
                    }
                    GameAudio.shared.voice(
                        freq: GameAudio.shared.note(10, fever: false) * 2,
                        dur: 0.06, gain: 0.06
                    )
                    GameHaptics.buzz(.light, gap: 0)
                }
            }
        }
        flyers.removeAll { $0.done }

        if pendingGameOver {
            if money >= engine.config.cost {
                pendingGameOver = false
            } else if flyers.isEmpty, engine.balls.isEmpty {
                finishGame()
            }
        }
    }

    // MARK: - Storage (localStorage 相当)

    private func storedBest() -> Int {
        UserDefaults.standard.integer(forKey: "dotdrop-best-game")
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
