import XCTest
@testable import CareSuiteNative
final class RideMotionTests:XCTestCase {
    func testStationaryCurveAndBrakingPhysics()throws {
        let stopped=try RideMotion.sample(0,30);XCTAssertEqual(stopped.speed,0);XCTAssertEqual(stopped.roll,0);XCTAssertEqual(stopped.pitch,0)
        let curve=try RideMotion.sample(2,0);XCTAssertEqual(curve.lateral,pow(40/3.6,2)/500,accuracy:1e-10);XCTAssertEqual(curve.roll,0)
        let end=try RideMotion.sample(3,30);XCTAssertEqual(end.speed,0);XCTAssertEqual(end.longitudinal,0)
        let epsilon=0.0001,t=5.0
        let derivative=(RideMotion.input(1,t+epsilon).0-RideMotion.input(1,t-epsilon).0)/(2*epsilon)
        XCTAssertEqual(try RideMotion.sample(1,t).longitudinal,derivative,accuracy:1e-7)
    }
    func testFiniteBoundedFramesAndInvalidInputs()throws {
        for mode in 0...3 {for t in [0.0,1,5,10,25,30]{let f=try RideMotion.sample(mode,t);XCTAssertTrue(f.roll.isFinite&&f.pitch.isFinite&&f.lateral.isFinite);XCTAssertLessThanOrEqual(abs(f.roll),3);XCTAssertLessThanOrEqual(abs(f.pitch),3);XCTAssertGreaterThanOrEqual(f.speed,0)}}
        for t in [-1.0,31,.nan,.infinity]{XCTAssertThrowsError(try RideMotion.sample(1,t))}
        XCTAssertThrowsError(try RideMotion.sample(4,5))
    }
}
