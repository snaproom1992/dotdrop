import XCTest
@testable import DotDropEngine

final class SeededRandomTests: XCTestCase {
    func testSeededSequenceIsStable() {
        let a = SeededRandom(seed: 42)
        let b = SeededRandom(seed: 42)
        let seqA = (0..<8).map { _ in a.next() }
        let seqB = (0..<8).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    func testDifferentSeedsDiverge() {
        let a = SeededRandom(seed: 1).next()
        let b = SeededRandom(seed: 2).next()
        XCTAssertNotEqual(a, b)
    }

    /// dump-fixtures.js の seededSample42 と一致すること（JS seeded との同一性）。
    func testMatchesJavaScriptSeededSample() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "shots", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "shots", withExtension: "json")
        )
        let root = try JSONDecoder().decode(FixtureFile.self, from: Data(contentsOf: url))
        let expected = try XCTUnwrap(root.seededSample42)
        let rng = SeededRandom(seed: 42)
        for (i, exp) in expected.enumerated() {
            XCTAssertEqual(rng.next(), exp, accuracy: 1e-12, "index \(i)")
        }
    }
}

final class FixtureParityTests: XCTestCase {
    /// JS の dump-fixtures.js が出した JSON と、Swift Engine を突き合わせる。
    /// フェーズ0ではファイルの形だけ検証。物理一致は Engine 移植後。
    func testFixtureFileShape() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "shots", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "shots", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let root = try JSONDecoder().decode(FixtureFile.self, from: data)
        XCTAssertEqual(root.version, 1)
        XCTAssertFalse(root.shots.isEmpty)

        // 移植後: 各 shot について Engine を回し、hitCount / shotPay / shotScore を比較する
        for shot in root.shots {
            XCTAssertGreaterThanOrEqual(shot.boardSeed, 0)
            XCTAssertEqual(shot.step, Engine.physicsSubstep, accuracy: 1e-12)
        }
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
    var expected: ShotExpected
}

struct ShotExpected: Decodable {
    var hitCount: Int
    var shotPay: Int
    var shotScore: Int
    var kinds: [String: Int]?
    var stuck: Bool
}
