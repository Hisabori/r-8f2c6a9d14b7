import XCTest
final class PreviewUITests:XCTestCase {
    func testCalculationAndBackgroundStop(){
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(app.navigationBars["전철 흔들림 실험"].waitForExistence(timeout:20))
        let calculate=app.buttons["ride-motion-calculate"]
        for _ in 0..<6{if calculate.isHittable{break};app.swipeUp()};XCTAssertTrue(calculate.isHittable);calculate.tap()
        for _ in 0..<6{if app.staticTexts["ride-motion-status"].isHittable{break};app.swipeDown()}
        XCTAssertEqual(app.staticTexts["ride-motion-status"].label,"가상 조건의 5초 시점 계산값입니다.")
        let play=app.buttons["흔들림 재생 · 최대 30초"]
        for _ in 0..<6{if play.isHittable{break};app.swipeUp()}
        if play.isEnabled{play.tap();XCUIDevice.shared.press(.home);app.activate();for _ in 0..<6{if app.staticTexts["ride-motion-status"].isHittable{break};app.swipeDown()};XCTAssertEqual(app.staticTexts["ride-motion-status"].label,"화면을 떠나 재생을 중지했습니다.")}
        XCTAssertEqual(app.state,.runningForeground)
        let screenshot=XCTAttachment(screenshot:app.screenshot());screenshot.name="Preview calculation screen";screenshot.lifetime = .keepAlways;add(screenshot)
    }
}
