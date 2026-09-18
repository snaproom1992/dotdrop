import XCTest
@testable import DotDropEngine

final class SeededRandomTests: XCTestCase {
    func testSeededSequenceIsStable() {
        let a = SeededRandom(seed: 42)
        let b = SeededRandom(seed: 42)
        XCTAssertEqual((0..<8).map { _ in a.next() }, (0..<8).map { _ in b.next() })
    }

    func testMatchesJavaScriptSeededSample() throws {
        let root = try Self.loadFixtures()
        let expected = try XCTUnwrap(root.seededSample42)
        let rng = SeededRandom(seed: 42)
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(rng.next(), exp, accuracy: 1e-12, "index \(i)")
        }
    }
}

final class FixtureParityTests: XCTestCase {
    func testFixtureFileShape() throws {
        let root = try Self.loadFixtures()
        XCTAssertEqual(root.version, 2)
        XCTAssertFalse(root.shots.isEmpty)
    }

    /// JS と同じ釘・同じ乱数・同じ発射で、hitCount / shotPay / shotScore が一致する。
    func testPhysicsMatchesJavaScriptFixtures() throws {
        let root = try Self.loadFixtures()
        for shot in root.shots {
            let play = SeededRandom(seed: shot.playSeed ?? 0)
            let engine = Engine(playRandom: play)
            engine.applyConf(.freePlay)
            engine.boardSeed = shot.boardSeed
            engine.stage = shot.stage
            engine.fever = shot.fever
            engine.convHold = false
            engine.conveyor = 0
            engine.time = 0

            let pegs = shot.pegs.map { (x: $0.x, y: $0.y, kind: PegKind(rawValue: $0.kind)!) }
            engine.loadPegs(pegs)
            engine.launch(vx: shot.launch.vx, vy: shot.launch.vy)

            let finished = engine.runShotToEnd(maxTime: shot.maxTime)
            XCTAssertEqual(!finished, shot.expected.stuck, shot.id)
            XCTAssertEqual(engine.hitCount, shot.expected.hitCount, "\(shot.id) hitCount")
            XCTAssertEqual(engine.shotPay, shot.expected.shotPay, "\(shot.id) shotPay")
            XCTAssertEqual(engine.shotScore, shot.expected.shotScore, "\(shot.id) shotScore")
        }
    }

    /// setLayout + pickGold が JS と同じ釘配置になる（Fisher–Yates + boardSeed）。
    func testSetLayoutMatchesFixturePegs() throws {
        let root = try Self.loadFixtures()
        for shot in root.shots {
            let engine = Engine()
            engine.applyConf(.freePlay)
            engine.boardSeed = shot.boardSeed
            engine.logicalHeight = 700
            engine.setLayout(shot.layout, animate: false)

            XCTAssertEqual(engine.pegs.count, shot.pegs.count, shot.id)
            for (i, exp) in shot.pegs.enumerated() {
                let p = engine.pegs[i]
                XCTAssertEqual(p.x, exp.x, accuracy: 1e-6, "\(shot.id) peg[\(i)].x")
                XCTAssertEqual(p.y, exp.y, accuracy: 1e-6, "\(shot.id) peg[\(i)].y")
                XCTAssertEqual(p.kind.rawValue, exp.kind, "\(shot.id) peg[\(i)].kind")
            }
        }
    }

    static func loadFixtures() throws -> FixtureFile {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "shots", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "shots", withExtension: "json")
        )
        return try JSONDecoder().decode(FixtureFile.self, from: Data(contentsOf: url))
    }
}

struct FixtureFile: Decodable {
    var version: Int
    var note: String?
    var seededSample42: [Double]?
    var shots: [ShotFixture]
}

struct ShotFixture: Decodable {
    var id: String
    var boardSeed: Int
    var layout: Int
    var stage: Int
    var fever: Bool
    var angleDeg: Double
    var level: Int
    var playSeed: Int?
    var exact: Bool
    var step: Double
    var maxTime: Double
    var launch: LaunchFixture
    var pegs: [PegFixture]
    var expected: ShotExpected
}

struct LaunchFixture: Decodable {
    var vx: Double
    var vy: Double
}

struct PegFixture: Decodable {
    var x: Double
    var y: Double
    var kind: String
}

struct ShotExpected: Decodable {
    var hitCount: Int
    var shotPay: Int
    var shotScore: Int
    var kinds: [String: Int]?
    var stuck: Bool
}
