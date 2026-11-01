import XCTest
@testable import CareSuiteNative
final class MedicationBagTextTests: XCTestCase {
 func testSeparatesCandidatesAndPreservesOriginal() {
  let text = "타이레놀정 500mg\n아침 식후 30분 복용\n환자 성명 홍길동\n전화 010-1234-5678\n타이레놀정 500mg"
  XCTAssertEqual(MedicationBagText.candidates(text, instructions: false), ["타이레놀정 500mg"])
  XCTAssertEqual(MedicationBagText.candidates(text, instructions: true), ["아침 식후 30분 복용"])
 }
 func testPrivateAndUnknownLinesAreNotSuggested() {
  let text = "환자 아침 복용\n성명 타이레놀정\n010-1234-5678 복용\n주소 서울정\nfoo@example.com 식후"
  XCTAssertTrue(MedicationBagText.candidates(text, instructions: false).isEmpty)
  XCTAssertTrue(MedicationBagText.candidates(text, instructions: true).isEmpty)
  XCTAssertTrue(MedicationBagText.candidates("홍길동\n병원", instructions: false).isEmpty)
 }
 func testAppendPreservesLinesAndAvoidsExactDuplicate() {
  XCTAssertEqual(MedicationBagText.append("식후", to: "아침"), "아침\n식후")
  XCTAssertEqual(MedicationBagText.append(" 식후 ", to: "아침\n식후"), "아침\n식후")
 }
 func testAppendRejectsOverflowWithoutTruncation() {
  XCTAssertNil(MedicationBagText.append("추가", to: String(repeating: "가", count: 200)))
  XCTAssertEqual(MedicationBagText.append("", to: "기존"), "기존")
 }
 func testSelectedTextKeepsLinesWithoutParsingSchedule() {
  XCTAssertEqual(MedicationBagText.importedText("  A정 10mg\n식후 복용  "), "A정 10mg\n식후 복용")
 }
 func testSelectedTextRejectsEmptyNullAndOversizedRows() {
  XCTAssertNil(MedicationBagText.importedText(" \n")); XCTAssertNil(MedicationBagText.importedText("A\0B"))
  XCTAssertNil(MedicationBagText.importedText(String(repeating: "가", count: 501)))
 }
 func testSelectedTextRejectsTooManyLinesAndHugePayload() {
  XCTAssertNil(MedicationBagText.importedText(Array(repeating: "A", count: 101).joined(separator: "\n")))
  XCTAssertNil(MedicationBagText.importedText(String(repeating: "A", count: 12001)))
  XCTAssertNotNil(MedicationBagText.importedText(String(repeating: "A", count: 500)))
 }
 func testGroupedCandidatesPreserveOrderAndFirstSpelling() {
  let result = MedicationBagText.analyze(MedicationBagText.lines("A정 10mg\n식후 복용\na정 10mg\n식후 복용\n성명 A정\nB캡슐"))
  XCTAssertEqual(result.names, ["A정 10mg", "B캡슐"]); XCTAssertEqual(result.instructions, ["식후 복용"])
 }
 func testFreshGroupsDoNotRetainPreviousText() {
  let before = MedicationBagText.analyze(["A정"]), after = MedicationBagText.analyze([])
  XCTAssertEqual(before.names, ["A정"]); XCTAssertTrue(after.names.isEmpty); XCTAssertTrue(after.instructions.isEmpty)
 }
}
