import XCTest
final class NativeNavigationTests: XCTestCase {
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
