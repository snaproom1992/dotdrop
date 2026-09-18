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

    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var triBonus = false
    @ObservationIgnored private var bestAtStart = 0
    @ObservationIgnored private var displayTimer: Timer?

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

    func applyFit(_ fit: BoardFit) {
        let lh = fit.logicalHeight
        guard abs(engine.logicalHeight - lh) > 0.5 else { return }
        engine.logicalHeight = lh
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
        lastDate = nil
        wireHooks()
        GameAudio.shared.playShoot()
        GameHaptics.buzz(.light, gap: 0)
    }

    private func wireHooks() {
        engine.hooks.hit = { [weak self] _, _, n, _, kind, pts in
            guard let self else { return }
            if !self.engine.fever { self.gauge += pts }
            if !self.triBonus {
                let tris = self.engine.pegs.filter { $0.kind == .tri }
                if tris.count == self.engine.config.tris, tris.allSatisfy(\.triHit) {
                    self.triBonus = true
                    self.money += 3
                    self.showBanner("▲▲▲", "3つとも当てて +3玉", DD.mustard)
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
        engine.hooks.shotEnd = { [weak self] pay in
            guard let self else { return }
            self.score += self.engine.shotScore
            self.money += pay
            self.gameBestShot = max(self.gameBestShot, self.engine.shotScore)
            if !self.beatBest, self.bestAtStart > 0, self.score > self.bestAtStart {
                self.beatBest = true
                self.showBanner("NEW RECORD", "自己ベスト\(self.bestAtStart)を超えた", DD.red)
            }
            self.busy = false
            self.feverStep()
            self.afterShot()
            if self.money < self.engine.config.cost {
                self.finishGame()
            }
        }
        engine.hooks.perfect = { [weak self] bonus in
            self?.showBanner("PERFECT", "ドットをすべて赤くした +\(bonus)", DD.red)
        }
        engine.hooks.land = { _, _, _ in }
        engine.hooks.release = { _, _ in }
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
        saveBest(score)
        personalBest = storedBest()
        screen = .result
        busy = false
    }

    func showBanner(_ word: String, _ sub: String, _ color: Color) {
        banner = Banner(word: word, sub: sub, color: color, born: Date())
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
