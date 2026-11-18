import XCTest
@testable import CareSuiteNative
final class StartupRevealTests: XCTestCase {
    @MainActor func testOnlyFirstSceneClaimsReveal() {
        let gate = NativeStartupGate()
        XCTAssertTrue(gate.claim()); XCTAssertFalse(gate.claim())
        gate.finish(); XCTAssertTrue(gate.finished); XCTAssertFalse(gate.claim())
    }
    @MainActor func testEarlyRouteFinishesBeforeClaim() {
        let gate = NativeStartupGate(); gate.finish()
        XCTAssertFalse(gate.claim()); XCTAssertTrue(gate.finished)
    }
}
