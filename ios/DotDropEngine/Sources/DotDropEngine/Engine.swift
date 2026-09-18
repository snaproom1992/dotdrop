import Foundation

/// パッケージのメタ情報。アプリのプレースホルダ表示用。
public enum EngineInfo {
    public static let version = "0.1.0-scaffold"
    /// Web ENGINE の LW と同じ
    public static let logicalWidth: Double = 360
}

/// 差し替え可能な乱数。フィクスチャ突き合わせ用。
public protocol RandomSource: AnyObject {
    func next() -> Double
}

public final class SystemRandom: RandomSource {
    public init() {}
    public func next() -> Double { Double.random(in: 0..<1) }
}

/// Web の `seeded()` と同じアルゴリズム（JS の Int32 / Math.imul 相当）。
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

/// 物理エンジン本体（フェーズ1で JS ENGINE を移植する）。
/// 今は定数と空の状態だけ。画面には触れない。
public final class Engine {
    public static let ballRadius: Double = 7
    public static let pegRadius: Double = 4.5
    public static let gravity: Double = 1100
    public static let conveyorSpeed: Double = 26
    public static let slotWidth: Double = 60
    public static let physicsSubstep: Double = 1.0 / 360.0

    public var logicalHeight: Double = 700
    public var pegs: [Peg] = []
    public var balls: [Ball] = []
    public var pot: Int = 0
    public var shotPay: Int = 0
    public var shotScore: Int = 0
    public var hitCount: Int = 0
    public var conveyor: Double = 0
    public var layout: Int = 0
    public var fever: Bool = false
    public var time: Double = 0
    public var stage: Int = 0
    public var boardSeed: Int? = nil
    public var convHold: Bool = false

    public var boardRandom: RandomSource
    public var playRandom: RandomSource

    public init(
        boardRandom: RandomSource = SystemRandom(),
        playRandom: RandomSource = SystemRandom()
    ) {
        self.boardRandom = boardRandom
        self.playRandom = playRandom
    }

    /// Web の `applyConf` 相当。フェーズ1で中身を埋める。
    public func applyConf(_ conf: EngineConfig = .freePlay) {
        _ = conf
    }

    /// Web の `stepPhysics` 相当。未実装。
    public func stepPhysics(dt: Double) {
        time += dt
        // TODO: port from index.html /*ENGINE*/
    }
}

public struct EngineConfig: Equatable, Sendable {
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
        startBalls: 12, cost: 1, maxBalls: 27,
        squares: 3, blues: 2, tris: 3,
        shotsPerBoard: 6, feverAt: 120, feverShots: 3, perfect: 500
    )
}

public struct Peg: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var kind: PegKind
    public var boardHit: Bool
    public init(x: Double, y: Double, kind: PegKind = .dot, boardHit: Bool = false) {
        self.x = x; self.y = y; self.kind = kind; self.boardHit = boardHit
    }
}

public enum PegKind: String, Equatable, Sendable {
    case dot, square, blue, tri
}

public struct Ball: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var state: BallState
    public init(x: Double, y: Double, vx: Double, vy: Double, state: BallState = .fly) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.state = state
    }
}

public enum BallState: String, Equatable, Sendable {
    case fly, held, land
}
