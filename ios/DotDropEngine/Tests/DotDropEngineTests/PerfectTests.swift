import XCTest
@testable import DotDropEngine

final class PerfectTests: XCTestCase {
    func testPerfectIsDeliveredOncePerBoardBeforeShotEnd() {
        let engine = Engine()
        engine.applyConf(.freePlay)
        engine.loadPegs([(x: 180, y: 250, kind: .dot)])
        engine.pegs[0].boardHit = true
        var delivered = 0
        var events: [String] = []
        engine.hooks.perfect = { bonus in delivered += bonus; events.append("perfect") }
        engine.hooks.shotEnd = { _ in events.append("end") }

        func finishBall() {
            let ball = Ball(x: 180, y: engine.slotTop(), vx: 0, vy: 0, state: .land)
            ball.landT = 0.51
            engine.balls = [ball]
            engine.stepPhysics(dt: Engine.physicsSubstep)
        }
        finishBall()
        XCTAssertEqual(engine.shotScore, 500)
        XCTAssertEqual(delivered, 500)
        XCTAssertEqual(events, ["perfect", "end"])
        finishBall()
        XCTAssertEqual(delivered, 500)
        XCTAssertEqual(engine.shotScore, 500)
        XCTAssertEqual(events, ["perfect", "end", "end"])
    }

    func testTutorialConfigurationSuppressesPerfect() {
        let engine = Engine()
        var config = EngineConfig.freePlay
        config.perfect = 0
        engine.applyConf(config)
        engine.loadPegs([(x: 180, y: 250, kind: .dot)])
        engine.pegs[0].boardHit = true
        engine.hooks.perfect = { _ in XCTFail("Tutorial must not award PERFECT") }
        let ball = Ball(x: 180, y: engine.slotTop(), vx: 0, vy: 0, state: .land)
        ball.landT = 0.51
        engine.balls = [ball]
        engine.stepPhysics(dt: Engine.physicsSubstep)
        XCTAssertEqual(engine.shotScore, 0)
    }
}
