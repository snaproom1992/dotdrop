import Foundation

// MARK: - Info

public enum EngineInfo {
    public static let version = "0.1.0-engine"
    public static let logicalWidth: Double = Engine.logicalWidth
}

// MARK: - Random

public protocol RandomSource: AnyObject {
    func next() -> Double
}

public final class SystemRandom: RandomSource {
    public init() {}
    public func next() -> Double { Double.random(in: 0..<1) }
}

/// Web の `seeded()` と同じ（JS Int32 / Math.imul 相当）。
public final class SeededRandom: RandomSource {
    private var state: Int32
    public init(seed: Int) {
        self.state = Int32(truncatingIfNeeded: seed)
    }
    public func next() -> Double {
        state &+= Int32(bitPattern: 0x6D2B79F5)
        var t = Self.imul(state ^ Int32(bitPattern: UInt32(bitPattern: state) >> 15), 1 | state)
        t = t &+ Self.imul(t ^ Int32(bitPattern: UInt32(bitPattern: t) >> 7), 61 | t) ^ t
        let mixed = UInt32(bitPattern: t ^ Int32(bitPattern: UInt32(bitPattern: t) >> 14))
        return Double(mixed) / 4294967296.0
    }
    private static func imul(_ a: Int32, _ b: Int32) -> Int32 {
        Int32(truncatingIfNeeded: Int64(a) * Int64(b))
    }
}

// MARK: - Config / types

public struct EngineConfig: Equatable, Sendable {
    public var slotM: [Int]
    public var stageB: [[Int]]
    public var startBalls: Int
    public var cost: Int
    public var maxBalls: Int
    public var squares: Int
    public var blues: Int
    public var tris: Int
    public var shotsPerBoard: Int
    public var feverAt: Int
    public var feverShots: Int
    public var perfect: Int

    public static let freePlay = EngineConfig(
        slotM: [0, 1, 3, 0, 0, 1, 5, 0, 0, 1, 3, 0, 0, 1, 3, 0],
        stageB: [
            [0, 1, 2, 0, -1, 0, 3, 0, -1, 0, 1, 0, 0, 0, 2, -1],
            [0, 0, 1, 0, -1, 0, 3, 0, -1, 0, 1, 0, 0, 0, 1, -1],
            [0, 0, 1, 0, 0, 0, 3, 0, -3, 0, 1, 0, 0, 0, 1, -1],
            [-1, 0, 0, 0, -1, 0, 3, 0, -3, 0, 1, 0, 0, 0, 1, -1],
            [-1, 0, 0, 0, -1, 0, 2, 0, -3, 0, 0, -1, 0, 0, 1, -1],
            [-1, 0, 0, 0, -1, 0, 2, 0, -3, 0, 0, -1, 0, 0, 1, -1],
            [-1, 0, 0, 0, 0, -1, 2, 0, -3, 0, 0, -1, 0, 0, 1, -1],
            [-1, 0, 0, 0, 0, -1, 2, 0, -3, 0, 0, -1, 0, 0, 1, -1],
            [-1, 0, 0, 0, 0, -1, 2, 0, -3, 0, 0, -1, 0, 0, 1, -1],
            [-1, 0, 0, 0, 0, -2, 2, 0, -3, 0, 0, -1, 0, 0, 0, -1],
            [-1, 0, 0, 0, 0, -2, 2, 0, -3, 0, 0, -1, 0, 0, 0, -1],
            [-1, 0, 0, 0, 0, -2, 2, 0, -3, 0, 0, -1, 0, 0, 0, -1],
            [-1, 0, 0, 0, 0, -2, 2, 0, -3, 0, 0, -1, -1, 0, 0, -1],
        ],
        startBalls: 12, cost: 1, maxBalls: 27,
        squares: 3, blues: 2, tris: 3,
        shotsPerBoard: 6, feverAt: 120, feverShots: 3, perfect: 500
    )
}

public enum PegKind: String, Equatable, Sendable, Codable {
    case dot, square, blue, tri
}

public enum BallState: String, Equatable, Sendable {
    case fly, held, land
}

public final class Peg {
    public var x: Double
    public var y: Double
    public var fx: Double
    public var fy: Double
    public var tx: Double
    public var ty: Double
    public var m: Double
    public var lit: Double
    public var pulse: Double
    public var kind: PegKind
    public var cool: Double
    public var boardHit: Bool
    public var triHit: Bool

    public init(
        x: Double, y: Double, kind: PegKind = .dot,
        fx: Double? = nil, fy: Double? = nil, tx: Double? = nil, ty: Double? = nil,
        m: Double = 1, lit: Double = 0, pulse: Double = 0, cool: Double = 0,
        boardHit: Bool = false, triHit: Bool = false
    ) {
        self.x = x; self.y = y
        self.fx = fx ?? x; self.fy = fy ?? y
        self.tx = tx ?? x; self.ty = ty ?? y
        self.m = m; self.lit = lit; self.pulse = pulse
        self.kind = kind; self.cool = cool
        self.boardHit = boardHit; self.triHit = triHit
    }
}

public final class Ball {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var state: BallState
    public var age: Double
    public var slot: Int
    public var landT: Double
    public var holdCool: Double
    public var pts: Int
    public var pay: Int
    public var mult: Int
    public var gain: Int
    public var hold: Peg?
    public var holdT: Double
    public var lastPeg: Peg?
    public var samePeg: Int
    public var lx: Double?
    public var ly: Double?
    public var stillT: Double
    public var stuckCount: Int
    public var ghostUntil: Double
    /// 飛んでいるあいだの軌跡（描画用・最大8）
    public var trail: [(Double, Double)]

    public init(x: Double, y: Double, vx: Double, vy: Double, state: BallState = .fly) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.state = state
        self.age = 0; self.slot = -1; self.landT = 0; self.holdCool = 0
        self.pts = 0; self.pay = 0; self.mult = 0; self.gain = 0
        self.hold = nil; self.holdT = 0; self.lastPeg = nil; self.samePeg = 0
        self.lx = nil; self.ly = nil; self.stillT = 0; self.stuckCount = 0
        self.ghostUntil = 0
        self.trail = []
    }
}

public struct EngineHooks {
    public var hit: (_ peg: Peg, _ ball: Ball, _ hitCount: Int, _ force: Double, _ kind: PegKind, _ pts: Int) -> Void
    public var land: (_ ball: Ball, _ pay: Int, _ raw: Int) -> Void
    public var shotEnd: (_ shotPay: Int) -> Void
    public var release: (_ peg: Peg, _ ball: Ball) -> Void
    public var perfect: (_ bonus: Int) -> Void

    public init() {
        hit = { _, _, _, _, _, _ in }
        land = { _, _, _ in }
        shotEnd = { _ in }
        release = { _, _ in }
        perfect = { _ in }
    }
}

// MARK: - Engine

/// `index.html` の /*ENGINE*/ 〜 /*END*/ の Swift 移植。画面には触れない。
public final class Engine {
    public static let logicalWidth: Double = 360
    public static let ballRadius: Double = 7
    public static let pegRadius: Double = 4.5
    public static let gravity: Double = 1100
    public static let conveyorSpeed: Double = 26
    public static let slotWidth: Double = 60
    public static let squareHalf: Double = 7
    public static let blueRadius: Double = 9
    public static let triRadius: Double = 8
    public static let physicsSubstep: Double = 1.0 / 360.0
    /// 基準の発射 Y。ノッチ分は `launchY` に上乗せする（帯 BANNER_Y と同じ考え方）
    public static let baseLaunchY: Double = 140
    public static let layouts = 4
    public static let maxPull: Double = 130
    public static let levels = 5

    public var logicalHeight: Double = 700
    /// 発射位置 Y（論理座標）。`applyFit` でノッチ／画面の高さぶん下げる
    public var launchY: Double = baseLaunchY
    /// 釘フィールド上端。発射位置と同じだけ下げる（間隔 60 を保つ）
    public var fieldTop: Double = 200
    /// 千鳥格子でおよそ 9 行（オリジナルの Safari 見た目）。これ以上は足さない
    public static let maxPegSpan: Double = 42 * 8
    public var launchPoint: (x: Double, y: Double) { (Self.logicalWidth / 2, launchY) }
    public var pegs: [Peg] = []
    public var balls: [Ball] = []
    public var pot: Int = 0
    public var shotPay: Int = 0
    public var shotScore: Int = 0
    public var hitCount: Int = 0
    public var split: Int = 0
    public var conveyor: Double = 0
    public var layout: Int = 0
    public var fever: Bool = false
    public var time: Double = 0
    public var stage: Int = 0
    public var boardSeed: Int? = nil
    public var convHold: Bool = false
    public var perfectDone: Bool = false
    public var hooks = EngineHooks()

    public private(set) var config: EngineConfig = .freePlay

    /// 台用。boardSeed があるときは seedBoard() で差し替える。
    public var boardRandom: RandomSource
    /// プレイ用（分裂・はね・青の放出・発射ブレ）。フィクスチャでは SeededRandom(playSeed)。
    public var playRandom: RandomSource

    private var boardRng: SeededRandom?

    public init(
        boardRandom: RandomSource = SystemRandom(),
        playRandom: RandomSource = SystemRandom()
    ) {
        self.boardRandom = boardRandom
        self.playRandom = playRandom
    }

    public var conveyorLength: Double { Double(config.slotM.count) * Self.slotWidth }

    public func applyConf(_ conf: EngineConfig = .freePlay) {
        config = conf
    }

    private func boardRand() -> Double {
        if let boardRng { return boardRng.next() }
        return boardRandom.next()
    }

    private func playRand() -> Double { playRandom.next() }

    /// 台を組み立てる前に呼ぶ。種があれば同じ台になる。
    public func seedBoard() {
        if let seed = boardSeed {
            boardRng = SeededRandom(seed: seed)
        } else {
            boardRng = nil
        }
    }

    public func slotTop() -> Double { logicalHeight - 84 }

    public func field() -> (top: Double, bottom: Double) {
        // ネイティブは Safari より画面が高いので、そのままだと釘の行が増えすぎる。
        // 受け皿の位置（slotTop）は logicalHeight のまま下端に置き、釘だけ行数を抑える。
        let natural = logicalHeight - 135
        let capped = fieldTop + Self.maxPegSpan
        return (fieldTop, min(natural, capped))
    }

    public func slotAt(_ x: Double, t: Double = 0) -> Int {
        let len = conveyorLength
        var u = (x - conveyor - Self.conveyorSpeed * t).truncatingRemainder(dividingBy: len)
        if u < 0 { u += len }
        return Int(floor(u / Self.slotWidth))
    }

    public func stageB(stage: Int? = nil) -> [Int] {
        let s = stage ?? self.stage
        let i = min(max(s, 0), config.stageB.count - 1)
        return config.stageB[i]
    }

    public func slotInfo(_ i: Int) -> (m: Int, b: Int) {
        let m = config.slotM[i]
        let b = stageB()[i]
        if fever {
            return (max(1, m), max(0, b))
        }
        return (m, b)
    }

    private static func shuffle<T>(_ arr: inout [T], rand: () -> Double) {
        var i = arr.count - 1
        while i > 0 {
            let j = Int(floor(rand() * Double(i + 1)))
            arr.swapAt(i, j)
            i -= 1
        }
    }

    public func makeLayout(_ kind: Int) -> [(Double, Double)] {
        let f = field()
        var pts: [(Double, Double)] = []
        let LW = Self.logicalWidth

        if kind == 0 {
            var r = 0
            var y = f.top
            while y <= f.bottom {
                let x0 = 34.0 + (r % 2 == 1 ? 22.0 : 0.0)
                var x = x0
                while x <= LW - 30 {
                    pts.append((x, y))
                    x += 44
                }
                y += 42
                r += 1
            }
        } else if kind == 1 {
            let cx = LW / 2, cy = (f.top + f.bottom) / 2
            pts.append((cx, cy))
            for ring in 1...7 {
                let rad = Double(ring) * 40
                let n = ring * 5
                for k in 0..<n {
                    let a = Double(k) / Double(n) * .pi * 2 + Double(ring) * 0.4
                    let x = cx + cos(a) * rad
                    let y = cy + sin(a) * rad
                    if x > 30 && x < LW - 30 && y > f.top - 6 && y < f.bottom + 6 {
                        pts.append((x, y))
                    }
                }
            }
        } else if kind == 2 {
            var r = 0
            var y = f.top
            while y <= f.bottom {
                for c in 0..<8 {
                    let x = 34 + Double(c) * 42 + sin(Double(r) * 0.8 + Double(c) * 0.7) * 18
                    pts.append((x, y))
                }
                y += 52
                r += 1
            }
        } else {
            var tries = 0
            while tries < 4000 {
                tries += 1
                let x = 30 + boardRand() * (LW - 60)
                let y = f.top + boardRand() * (f.bottom - f.top)
                if pts.allSatisfy({ hypot($0.0 - x, $0.1 - y) > 36 }) {
                    pts.append((x, y))
                }
            }
        }

        let clamped = pts.map { (max(30, min(LW - 30, $0.0)), $0.1) }
        var unique: [(Double, Double)] = []
        for p in clamped {
            if !unique.contains(where: { hypot($0.0 - p.0, $0.1 - p.1) < 20 }) {
                unique.append(p)
            }
        }
        return unique
    }

    public func setLayout(_ kind: Int, animate: Bool = false) {
        seedBoard()
        let pts = makeLayout(kind)
        let old = pegs
        layout = kind
        pegs = pts.enumerated().map { i, pt in
            let o = animate && !old.isEmpty ? old[i % old.count] : nil
            return Peg(
                x: o?.x ?? pt.0, y: o?.y ?? pt.1,
                kind: .dot,
                fx: o?.x ?? pt.0, fy: o?.y ?? pt.1,
                tx: pt.0, ty: pt.1,
                m: o == nil ? 1 : 0,
                boardHit: false
            )
        }
        perfectDone = false
        var idx = Array(pegs.indices)
        Self.shuffle(&idx, rand: { [self] in boardRand() })
        for i in idx.prefix(config.squares) { pegs[i].kind = .square }
        for i in idx.dropFirst(config.squares).prefix(config.blues) { pegs[i].kind = .blue }
        pickGold()
    }

    public func pickGold() {
        seedBoard()
        for p in pegs {
            p.triHit = false
            if p.kind == .tri { p.kind = .dot }
        }
        var dots = pegs.filter { $0.kind == .dot }
        Self.shuffle(&dots, rand: { [self] in boardRand() })
        for p in dots.prefix(config.tris) { p.kind = .tri }
    }

    /// フィクスチャ用：JS が出した釘配置をそのまま載せる。
    public func loadPegs(_ items: [(x: Double, y: Double, kind: PegKind)]) {
        pegs = items.map { Peg(x: $0.x, y: $0.y, kind: $0.kind) }
        perfectDone = false
    }

    public func launchVelocity(pullX: Double, pullY: Double, exact: Bool = false) -> (Double, Double) {
        let k = 3.2
        let jitter = exact ? 1.0 : 1.0 + (playRand() - 0.5) * 0.08
        let ang = exact ? 0.0 : (playRand() - 0.5) * 0.07
        var vx = -pullX * k * jitter
        var vy = -max(0, pullY) * k * jitter
        let c = cos(ang), s = sin(ang)
        let rx = vx * c - vy * s
        let ry = min(0, vx * s + vy * c)
        return (rx, ry)
    }

    public func launch(vx: Double, vy: Double) {
        pot = 0; shotPay = 0; hitCount = 0; shotScore = 0
        let L = launchPoint
        balls = [Ball(x: L.x, y: L.y, vx: vx, vy: vy)]
    }

    private static let points: [PegKind: Int] = [
        .dot: 1, .square: 3, .blue: 2, .tri: 1
    ]

    private func hitPeg(_ p: Peg, _ b: Ball, force: Double) {
        hitCount += 1
        let kind = p.kind
        let pts = (Self.points[kind] ?? 1) * (fever ? 2 : 1)
        pot += pts
        b.pts += pts
        p.lit = 1; p.pulse = 1; p.boardHit = true
        var splitCount = 0
        if kind == .tri {
            p.triHit = true
            p.cool = time + 0.35
            for dir in [-1.0, 1.0] {
                if balls.count >= config.maxBalls { break }
                let nb = Ball(
                    x: b.x + dir * 4, y: b.y,
                    vx: dir * (160 + playRand() * 80),
                    vy: -140 - playRand() * 60
                )
                balls.append(nb)
                splitCount += 1
            }
        }
        split = splitCount
        hooks.hit(p, b, hitCount, force, kind, pts)
    }

    public func stepPhysics(dt: Double) {
        time += dt
        if !convHold { conveyor += Self.conveyorSpeed * dt }
        let BR = Self.ballRadius
        let LW = Self.logicalWidth
        let n = balls.count

        for i in 0..<n {
            let b = balls[i]
            if b.state == .land {
                b.landT += dt
                if !convHold { b.x += Self.conveyorSpeed * dt }
                continue
            }
            if b.state == .held {
                guard let p = b.hold else { continue }
                b.holdT += dt
                b.x = p.x; b.y = p.y
                if b.holdT > 0.5 {
                    let ang = (playRand() - 0.5) * 2.2
                    let sp = 300.0
                    b.vx = sin(ang) * sp
                    b.vy = cos(ang) * sp
                    b.x = p.x + sin(ang) * (Self.blueRadius + BR + 1)
                    b.y = p.y + cos(ang) * (Self.blueRadius + BR + 1)
                    b.state = .fly
                    b.holdCool = time + 0.6
                    hooks.release(p, b)
                }
                continue
            }

            b.age += dt
            b.vy += Self.gravity * dt
            b.x += b.vx * dt
            b.y += b.vy * dt
            if b.y < 40 && b.vy < 0 { b.y = 40; b.vy = -b.vy * 0.4 }
            if b.x < BR { b.x = BR; b.vx = max(abs(b.vx) * 0.8, 150) }
            if b.x > LW - BR { b.x = LW - BR; b.vx = -max(abs(b.vx) * 0.8, 150) }

            let pegsToTest: [Peg] = b.ghostUntil > time ? [] : pegs
            for p in pegsToTest {
                let reach = BR + 10
                let dx0 = b.x - p.x, dy0 = b.y - p.y
                if dx0 > reach || dx0 < -reach || dy0 > reach || dy0 < -reach { continue }

                if p.kind == .square {
                    let SQ = Self.squareHalf
                    let cx = max(p.x - SQ, min(b.x, p.x + SQ))
                    let cy = max(p.y - SQ, min(b.y, p.y + SQ))
                    var dx = b.x - cx, dy = b.y - cy
                    var d = hypot(dx, dy)
                    if d >= BR { continue }
                    if d < 0.001 { dx = 0; dy = -1; d = 1 }
                    let nx = dx / d, ny = dy / d
                    b.x = cx + nx * BR
                    b.y = cy + ny * BR
                    let vn = b.vx * nx + b.vy * ny
                    if vn < 0 {
                        b.vx -= 2 * vn * nx
                        b.vy -= 2 * vn * ny
                        let sp = hypot(b.vx, b.vy)
                        if sp < 560 { b.vx *= 560 / sp; b.vy *= 560 / sp }
                        b.vx += (playRand() - 0.5) * 120
                        b.samePeg = (b.lastPeg === p) ? b.samePeg + 1 : 0
                        b.lastPeg = p
                        if b.samePeg > 2 {
                            b.vx = (b.x < p.x ? -1 : 1) * 260
                            b.samePeg = 0
                        }
                        if time > p.cool {
                            p.cool = time + 0.12
                            hitPeg(p, b, force: -vn)
                        }
                    }
                    continue
                }

                let m = BR + (p.kind == .blue ? Self.blueRadius : p.kind == .tri ? Self.triRadius : Self.pegRadius)
                let d = hypot(dx0, dy0)
                if d < m && d > 0.001 {
                    if p.kind == .blue && time > b.holdCool {
                        b.state = .held
                        b.hold = p
                        b.holdT = 0
                        b.trail = []
                        hitPeg(p, b, force: 300)
                        break
                    }
                    let nx = dx0 / d, ny = dy0 / d
                    b.x = p.x + nx * m
                    b.y = p.y + ny * m
                    let vn = b.vx * nx + b.vy * ny
                    if vn < 0 {
                        b.vx -= 1.55 * vn * nx
                        b.vy -= 1.55 * vn * ny
                        b.vx += (playRand() - 0.5) * 50
                        if time > p.cool {
                            p.cool = time + 0.12
                            hitPeg(p, b, force: -vn)
                        }
                    }
                }
            }

            if b.state == .held { continue }

            let prevX = b.lx ?? b.x
            let prevY = b.ly ?? b.y
            let moved = hypot(b.x - prevX, b.y - prevY)
            b.lx = b.x; b.ly = b.y
            if moved < 40 * dt { b.stillT += dt } else { b.stillT = 0 }
            if b.stillT > 0.3 {
                let dir: Double = b.x < LW / 2 ? 1 : -1
                b.vx = dir * (120 + playRand() * 80)
                b.vy = 160
                b.x += dir * 3
                b.stuckCount += 1
                b.stillT = 0
                if b.stuckCount >= 3 { b.ghostUntil = time + 0.25 }
            }
            let sp = hypot(b.vx, b.vy)
            if sp > 1000 { b.vx *= 1000 / sp; b.vy *= 1000 / sp }
            if b.age > 8 { b.vy += 3000 * dt }
            if b.y > slotTop() {
                b.state = .land
                b.y = slotTop()
                b.slot = slotAt(b.x)
                let info = slotInfo(b.slot)
                let v = info.b
                b.mult = info.m
                b.gain = b.pts * info.m
                shotScore += b.gain
                b.pay = v
                shotPay += v
                hooks.land(b, v, v)
            }
        }

        if !balls.isEmpty && balls.allSatisfy({ $0.state == .land && $0.landT > 0.5 }) {
            balls = []
            if config.perfect > 0 && !perfectDone && !pegs.isEmpty && pegs.allSatisfy(\.boardHit) {
                perfectDone = true
                shotScore += config.perfect
                hooks.perfect(config.perfect)
            }
            hooks.shotEnd(shotPay)
        }
    }

    /// 1打を最後まで進める（テスト・ヘッドレス用）。
    @discardableResult
    public func runShotToEnd(maxTime: Double = 40) -> Bool {
        let step = Self.physicsSubstep
        var t = 0.0
        var done = false
        let prev = hooks.shotEnd
        hooks.shotEnd = { pay in
            done = true
            prev(pay)
        }
        while !done && t < maxTime {
            stepPhysics(dt: step)
            t += step
        }
        hooks.shotEnd = prev
        return done
    }
}
