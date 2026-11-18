import XCTest
@testable import CryptoResearchKit
final class CommunitySummaryTests: XCTestCase {
    @MainActor func testInputBoundsAndDeduplication() {
        let input = CommunitySummarySession.clean(["  BTC\n호재 ","BTC 호재",""] + (0..<20).map { String($0)+String(repeating: "가", count: 180) })
        XCTAssertEqual(input.first,"BTC 호재"); XCTAssertEqual(input.count,12); XCTAssertTrue(input.allSatisfy { $0.count <= 120 }); XCTAssertEqual(input.filter { $0 == "BTC 호재" }.count,1)
    }
    @MainActor func testCancelledLateResponseCannotReplaceNewResult() async {
        let state = CommunitySummarySession(); var old: CheckedContinuation<String,Never>?
        state.start(["old"]) { _ in await withCheckedContinuation { old = $0 } }
        for _ in 0..<50 where old == nil { await Task.yield() }
        XCTAssertNotNil(old);state.cancel("중지")
        state.start(["new"]) { _ in "새 요약" }
        for _ in 0..<50 where state.busy { await Task.yield() }
        old?.resume(returning:"오래된 요약");await Task.yield()
        XCTAssertTrue(state.output.contains("새 요약"));XCTAssertFalse(state.output.contains("오래된 요약"));XCTAssertTrue(state.canCopy)
    }
    @MainActor func testTimeoutAndEmptyResponse() async throws {
        let state = CommunitySummarySession()
        state.start(["title"],timeout:1_000_000) { _ in try await Task.sleep(nanoseconds:1_000_000_000);return "늦음" }
        try await Task.sleep(nanoseconds:30_000_000);XCTAssertFalse(state.busy);XCTAssertFalse(state.canCopy)
        state.start(["title"]) { _ in " " };for _ in 0..<50 where state.busy { await Task.yield() }
        XCTAssertFalse(state.canCopy);XCTAssertTrue(state.output.contains("빈 응답"))
    }
}
