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
    func testPublicTransitOpensWithoutKeyAndKeepsTravelAvailable() {
        let app = XCUIApplication();app.launch()
        let travel = app.buttons["native-travel-open"]
        if !travel.isHittable { app.swipeUp() }
        XCTAssertTrue(travel.waitForExistence(timeout:20));travel.tap()
        let link = app.buttons["public-transit-open"]
        XCTAssertTrue(link.waitForExistence(timeout:10));link.tap()
        let station = app.textFields["public-transit-station"]
        XCTAssertTrue(station.waitForExistence(timeout:10));station.tap();station.typeText("서울")
        app.buttons["지하철 도착정보 조회"].tap()
        XCTAssertTrue(app.staticTexts["역 이름과 영문·숫자 인증키를 확인하세요."].waitForExistence(timeout:10))
        app.navigationBars.buttons.element(boundBy:0).tap()
        XCTAssertTrue(link.waitForExistence(timeout:10))
        XCTAssertEqual(app.state,.runningForeground)
    }
    func testStrategyComparisonRunsSyntheticWithoutOrders() {
        let app = XCUIApplication();app.launch()
        let investment = app.buttons["native-investment-open"]
        if !investment.isHittable { app.swipeUp() }
        XCTAssertTrue(investment.waitForExistence(timeout:20));investment.tap()
        let comparison = app.buttons["strategy-comparison-open"]
        if !comparison.isHittable { app.swipeUp() }
        XCTAssertTrue(comparison.waitForExistence(timeout:10));comparison.tap()
        let sample = app.buttons["strategy-comparison-sample"]
        XCTAssertTrue(sample.waitForExistence(timeout:10));sample.tap()
        XCTAssertTrue(app.staticTexts["합성 예제 · 실제 시장 성과 아님"].waitForExistence(timeout:20))
        XCTAssertEqual(app.state,.runningForeground)
    }
    func testTickerToComparisonAndReturnPreservesResult() {
        let app = XCUIApplication();app.launch()
        let investment = app.buttons["native-investment-open"]
        if !investment.isHittable { app.swipeUp() }
        XCTAssertTrue(investment.waitForExistence(timeout:20));investment.tap()
        let entry = app.buttons["ticker-research-open"]
        XCTAssertTrue(entry.waitForExistence(timeout:10));entry.tap()
        let sample = app.buttons["ticker-sample"]
        for _ in 0..<5 { if sample.isHittable { break };app.swipeUp() }
        XCTAssertTrue(sample.isHittable);sample.tap()
        let handoff = app.buttons["ticker-to-comparison"]
        for _ in 0..<5 { if handoff.isHittable { break };app.swipeUp() }
        XCTAssertTrue(handoff.waitForExistence(timeout:10));handoff.tap()
        let source = app.staticTexts["comparison-research-source"]
        XCTAssertTrue(source.waitForExistence(timeout:10));XCTAssertTrue(source.label.contains("합성"))
        let run = app.buttons["comparison-research-run"]
        if !run.isHittable { app.swipeUp() };run.tap()
        XCTAssertTrue(app.staticTexts["합성 예제 · 실제 시장 성과 아님"].waitForExistence(timeout:20))
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        let compare = app.buttons["strategy-comparison-open"]
        if !compare.isHittable { app.swipeUp() };compare.tap()
        let result = app.staticTexts["합성 예제 · 실제 시장 성과 아님"]
        if !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout:10));XCTAssertEqual(app.state,.runningForeground)
    }
    func testTradeConnectionRejectsPastedVariableWithoutNetwork() {
        let app = XCUIApplication();app.launch()
        let investment = app.buttons["native-investment-open"]
        if !investment.isHittable { app.swipeUp() }
        XCTAssertTrue(investment.waitForExistence(timeout:20));investment.tap()
        let settings = app.buttons["investment-settings-open"]
        if !settings.isHittable { app.swipeUp() };settings.tap()
        let guide = app.buttons["거래소 API 설정 가이드"]
        XCTAssertTrue(guide.waitForExistence(timeout:10));guide.tap()
        let address = app.textFields["trade-server-address"]
        XCTAssertTrue(address.waitForExistence(timeout:10));address.tap()
        let value = address.value as? String ?? ""
        address.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:value.count)+"https://fixture.invalid:8443")
        let token = app.secureTextFields["trade-server-token"]
        token.tap();token.typeText("TRADE_READ_TOKEN="+String(repeating:"x",count:48))
        let save = app.buttons["거래 서버 설정 저장"]
        for _ in 0..<4 { if save.isHittable { break };app.swipeUp() }
        save.tap()
        let message = app.staticTexts["trade-connection-message"]
        for _ in 0..<4 { if message.isHittable { break };app.swipeUp() }
        XCTAssertTrue(message.waitForExistence(timeout:10));XCTAssertTrue(message.label.contains("값만"))
        XCTAssertEqual(app.state,.runningForeground)
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
