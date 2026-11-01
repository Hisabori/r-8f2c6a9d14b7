import XCTest
final class NativeModulesTests:XCTestCase {
    func testHealthAndCryptoOpenAndReturnToOneHome(){
        let app=XCUIApplication();app.launch()
        let health=app.buttons["건강과 투약 살펴보기"]
        XCTAssertTrue(health.waitForExistence(timeout:30));health.tap()
        let closeHealth=app.buttons["super-close-health"]
        XCTAssertTrue(closeHealth.waitForExistence(timeout:20));closeHealth.tap()
        let crypto=app.buttons["투자와 리서치 살펴보기"]
        XCTAssertTrue(crypto.waitForExistence(timeout:10));crypto.tap()
        let closeCrypto=app.buttons["super-close-crypto"]
        XCTAssertTrue(closeCrypto.waitForExistence(timeout:20));closeCrypto.tap()
        XCTAssertTrue(health.waitForExistence(timeout:10))
    }
}
