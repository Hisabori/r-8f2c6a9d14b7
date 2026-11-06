import XCTest
final class NativeNavigationTests: XCTestCase {
    func testPetDraftSurvivesReturningHome() {
        let app = XCUIApplication();app.launch()
        let pet = app.buttons["native-pet-open"]
        XCTAssertTrue(pet.waitForExistence(timeout:20));pet.tap()
        let name = app.textFields["pet-draft-name"]
        XCTAssertTrue(name.waitForExistence(timeout:10));name.tap();name.typeText("Lulu")
        app.navigationBars.buttons.element(boundBy:0).tap()
        XCTAssertTrue(pet.waitForExistence(timeout:10));pet.tap()
        XCTAssertEqual(name.value as? String,"Lulu")
    }
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
    func testInvestmentStrategyAndSettingsFromHomeAndResume() {
        let app = XCUIApplication();app.launch()
        let investment = app.buttons["native-investment-open"]
        if !investment.isHittable { app.swipeUp() }
        XCTAssertTrue(investment.waitForExistence(timeout:20));investment.tap()
        checkInvestmentDestinations(app)
        app.navigationBars.buttons.element(boundBy:0).tap()
        let resume = app.buttons["native-service-resume"]
        if !resume.isHittable { app.swipeDown() }
        XCTAssertTrue(resume.waitForExistence(timeout:10));resume.tap()
        checkInvestmentDestinations(app)
        XCTAssertEqual(app.state,.runningForeground)
    }
    private func checkInvestmentDestinations(_ app: XCUIApplication) {
        for (id,title) in [("investment-market-open","마켓"),("investment-favorites-open","관심 종목"),("investment-strategy-open","연구실"),("investment-settings-open","설정")] {
            let link = app.buttons[id]
            XCTAssertTrue(link.waitForExistence(timeout:10))
            if !link.isHittable { app.swipeUp() }
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout:10))
            XCTAssertEqual(app.state,.runningForeground)
            if id == "investment-settings-open" {
                let guide = app.buttons["거래소 API 설정 가이드"]
                XCTAssertTrue(guide.waitForExistence(timeout:10));guide.tap()
                XCTAssertTrue(app.navigationBars["통합 거래소"].waitForExistence(timeout:10))
                XCTAssertEqual(app.state,.runningForeground)
                app.navigationBars.buttons.element(boundBy:0).tap()
            }
            app.navigationBars.buttons.element(boundBy:0).tap()
        }
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
