import XCTest
final class NavigationTests:XCTestCase {
 func testNativeTabsAndControls(){let app=XCUIApplication();app.launch();XCTAssertTrue(app.tabBars.buttons["마켓"].waitForExistence(timeout:10));XCTAssertTrue(app.buttons["실시간 시세 연결"].exists);app.tabBars.buttons["관심"].tap();XCTAssertTrue(app.navigationBars["관심 종목"].exists);app.tabBars.buttons["연구실"].tap();XCTAssertTrue(app.buttons["결과 JSON 열기"].waitForExistence(timeout:5));app.tabBars.buttons["설정"].tap();XCTAssertTrue(app.navigationBars["설정"].exists);let shot=XCTAttachment(screenshot:app.screenshot());shot.name="native-settings";shot.lifetime = .keepAlways;add(shot)}
}
