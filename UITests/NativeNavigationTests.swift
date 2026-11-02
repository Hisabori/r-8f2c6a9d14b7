import XCTest
final class NativeNavigationTests: XCTestCase {
    func testTickerAnalysisSampleIsExplicitlySynthetic() {
        let app = XCUIApplication();app.launch()
        let investment = app.buttons["native-investment-open"]
        XCTAssertTrue(investment.waitForExistence(timeout:20));investment.tap()
        let entry = app.buttons["ticker-research-open"]
        XCTAssertTrue(entry.waitForExistence(timeout:10));entry.tap()
        let sample = app.buttons["ticker-sample"]
        if !sample.isHittable { app.swipeUp() }
        XCTAssertTrue(sample.waitForExistence(timeout:10));sample.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["합성 예제 · 실제 시장 자료 아님"].waitForExistence(timeout:10))
        XCTAssertEqual(app.staticTexts["ticker-direction"].label,"판정 보류")
    }
    func testOnCareOwnsNavigationWithoutFlutterHost() {
        let app = XCUIApplication(); app.launch()
        for id in ["native-pet-open", "native-travel-open", "native-investment-open"] {
            let link = app.buttons[id]
            if !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.waitForExistence(timeout: 20)); link.tap()
            XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 20))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.tabBars.buttons["오늘"].waitForExistence(timeout: 10))
        }
    }
}
