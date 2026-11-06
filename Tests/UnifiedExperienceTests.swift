import XCTest
@testable import CareSuiteNative
@testable import CryptoResearchKit

final class UnifiedExperienceTests: XCTestCase {
    func testActivityProgressBoundsAndUnknownTotals() {
        XCTAssertNil(NativeActivityText.progress(processed:3,total:nil))
        XCTAssertNil(NativeActivityText.progress(processed:3,total:0))
        XCTAssertNil(NativeActivityText.progress(processed:3,total:100_001))
        XCTAssertEqual(NativeActivityText.progress(processed:-1,total:10),0)
        XCTAssertEqual(NativeActivityText.progress(processed:5,total:10),50)
        XCTAssertEqual(NativeActivityText.progress(processed:29,total:100),29)
        XCTAssertEqual(NativeActivityText.progress(processed:11,total:10),100)
    }
    func testActivityCountdownAndFreshnessBounds() {
        let now = Date(timeIntervalSince1970:1_750_000_000)
        XCTAssertEqual(NativeActivityText.countdownRange(until:now.addingTimeInterval(-20),now:now).upperBound,now)
        XCTAssertEqual(NativeActivityText.countdownRange(until:now.addingTimeInterval(4000),now:now).upperBound,now.addingTimeInterval(4000))
        XCTAssertFalse(NativeActivityText.researchStale(updated:now,stale:false,now:now))
        XCTAssertTrue(NativeActivityText.researchStale(updated:now.addingTimeInterval(-91),stale:false,now:now))
        XCTAssertTrue(NativeActivityText.researchStale(updated:now.addingTimeInterval(10),stale:false,now:now))
        XCTAssertTrue(NativeActivityText.researchStale(updated:now,stale:true,now:now))
    }
    @available(iOS 16.2, *)
    func testPreviousActivityPayloadsRemainDecodable() throws {
        let decoder = JSONDecoder()
        let travel = try decoder.decode(DepartureAttributes.ContentState.self,from:Data(#"{"leaveAt":100,"trainAt":200,"updatedAt":50}"#.utf8))
        XCTAssertNil(travel.plannedAt)
        XCTAssertNil(travel.departureAt)
        let pet = try decoder.decode(BarkAnalysisAttributes.ContentState.self,from:Data(#"{"signal":"processing","barkPercent":0,"elapsed":0,"processed":0,"positive":0,"updatedAt":50}"#.utf8))
        XCTAssertNil(pet.total)
    }
    func testManualTravelKeepsFixedPlanWhileRouteEstimatesExpire() {
        let now = Date(timeIntervalSince1970:1_750_000_000)
        let old = now.addingTimeInterval(-300), arrival = now.addingTimeInterval(3600)
        XCTAssertFalse(NativeActivityText.travelStale(manual:true,updated:old,arrival:arrival,stale:false,now:now))
        XCTAssertTrue(NativeActivityText.travelStale(manual:false,updated:old,arrival:arrival,stale:false,now:now))
        XCTAssertTrue(NativeActivityText.travelStale(manual:true,updated:old,arrival:now,stale:false,now:now))
        XCTAssertTrue(NativeActivityText.travelStale(manual:true,updated:now.addingTimeInterval(10),arrival:arrival,stale:false,now:now))
    }
    func testServiceLinksContainOnlyFixedDestinations() {
        for path in ["pet","travel","investment","ticker"] {
            XCTAssertEqual(NativeServiceDestination.parse(URL(string:"caresuite-care://service/"+path)!)?.rawValue,path)
        }
        for text in ["https://service/pet","caresuite-care://service/pet?token=x","caresuite-care://service/pet#secret","caresuite-care://user:secret@service/pet","caresuite-care://service:443/pet","caresuite-care://service/%70et","caresuite-care://service/pet/","caresuite-care://service/unknown"] {
            XCTAssertNil(NativeServiceDestination.parse(URL(string:text)!))
        }
    }
    @MainActor func testNewHealthIntentConsumesPendingServiceRoute() {
        let router = NativeServiceRouter.shared
        router.open(.pet)
        let health = CareShortcutRouter()
        health.open(.mood)
        XCTAssertNil(router.pending)
        XCTAssertEqual(health.pending?.destination,.mood)
    }
    func testLiveActivityUsesRecordingLanguageAndBoundedCompactNumbers() {
        XCTAssertEqual(NativeActivityText.pet("recording",stale:false),"소리 녹음 중")
        XCTAssertEqual(NativeActivityText.pet("recording",stale:true),"앱에서 상태 확인")
        XCTAssertEqual(NativeActivityText.pet("processing",stale:false),"녹음 파일 분석 중")
        XCTAssertEqual(NativeActivityText.compactSteps(-1),"0")
        XCTAssertEqual(NativeActivityText.compactSteps(10000),"1.0만")
        XCTAssertLessThanOrEqual(NativeActivityText.compactSteps(2_000_000).count,7)
    }
    func testLiveSnapshotFreshnessRejectsUnknownFutureAndExpiredValues() {
        let now = Date(timeIntervalSince1970:1000)
        XCTAssertTrue(NativeActivityText.fresh(now.addingTimeInterval(-120),at:now))
        XCTAssertFalse(NativeActivityText.fresh(now.addingTimeInterval(-121),at:now))
        XCTAssertFalse(NativeActivityText.fresh(now.addingTimeInterval(6),at:now))
        XCTAssertFalse(NativeActivityText.fresh(nil,at:now))
        XCTAssertFalse(NativeActivityText.fresh(now,at:now,maxAge:-1))
    }
    @MainActor func testWellbeingDiaryRequiresConsentAndRejectsSyntheticResearch() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store = WellbeingResearchStore(directory:folder)
        let now = Date(),context = WellbeingContext(sleepHours:6.5,sleepAt:now,moodValue:3,moodAt:now)
        let real = NativeResearchDigest(ticker:"AAPL",direction:"방향 혼재",analyzedAt:now,synthetic:false)
        store.save(condition:context,research:real,consented:false)
        XCTAssertTrue(store.records.isEmpty)
        let sample = NativeResearchDigest(ticker:"AAPL",direction:"판정 보류",analyzedAt:now,synthetic:true)
        store.save(condition:context,research:sample,consented:true)
        XCTAssertTrue(store.records.isEmpty)
        store.draft = "Synthetic local note"
        store.save(condition:context,research:real,consented:true,at:now)
        XCTAssertEqual(store.records.count,1)
        XCTAssertEqual(store.records.first?.condition.sleepHours,6.5)
        XCTAssertEqual(store.records.first?.research.direction,"방향 혼재")
        XCTAssertEqual(WellbeingResearchStore(directory:folder).records.count,1)
    }
    @MainActor func testUnreadableWellbeingDiaryIsNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let file = folder.appendingPathComponent("records-v1.json"),original = Data("corrupt synthetic fixture".utf8)
        try original.write(to:file)
        let store = WellbeingResearchStore(directory:folder)
        store.save(condition:WellbeingContext(sleepHours:nil,sleepAt:nil,moodValue:nil,moodAt:nil),research:NativeResearchDigest(ticker:"AAPL",direction:"방향 혼재",analyzedAt:Date(),synthetic:false),consented:true)
        XCTAssertEqual(try Data(contentsOf:file),original)
    }
    @MainActor func testSharedInvestmentSessionRetainsInputAndSnapshotWithoutHealthInput() {
        let suite = "test.research-session."+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let session = NativeInvestmentSession(defaults:defaults)
        session.researchTicker = "ETH"
        session.researchAsset = .crypto
        session.research.sample(try! ResearchTicker("ETH",asset:.crypto))
        XCTAssertEqual(session.researchTicker,"ETH")
        XCTAssertEqual(session.researchDigest?.ticker,"ETH/USDT")
        XCTAssertTrue(session.researchDigest?.synthetic == true)
        XCTAssertFalse(session.researchBusy)
        XCTAssertEqual(NativeInvestmentSession(defaults:defaults).researchTicker,"ETH")
    }
}
