import XCTest
@testable import CareSuiteNative
final class DeepMoodTests: XCTestCase {
    func testDraftKeepsOnlySelectedAllowedValuesWithinLimits() {
        let draft = DeepMood.draft(prompt: 0, focus: "관계", emotions: Set(DeepMood.emotions + ["injected"]), contexts: Set(DeepMood.contexts + ["unknown"]), intensity: nil, energy: "invalid")
        XCTAssertTrue(draft.contains("섞인 감정: 불안 · 서운함 · 외로움"))
        XCTAssertTrue(draft.contains("마음이 움직인 상황: 연락 · 관계"))
        XCTAssertFalse(draft.contains("injected")); XCTAssertFalse(draft.contains("unknown")); XCTAssertFalse(draft.contains("지금 에너지:"))
        XCTAssertLessThan(draft.count, 2000)
    }
    func testOmittedIntensityIsNotInventedAndZeroIsValid() {
        let empty = DeepMood.draft(prompt: 0, focus: "자유롭게", emotions: [], contexts: [], intensity: nil, energy: "선택 안 함")
        XCTAssertFalse(empty.contains("섞인 감정:")); XCTAssertFalse(empty.contains("내가 고른 강도:"))
        let zero = DeepMood.draft(prompt: 0, focus: "자유롭게", emotions: [], contexts: [], intensity: 0, energy: "중간")
        XCTAssertTrue(zero.contains("강도: 0/10")); XCTAssertTrue(zero.contains("에너지: 중간"))
        XCTAssertFalse(DeepMood.draft(prompt: 0, focus: "자유롭게", emotions: [], contexts: [], intensity: 11, energy: "선택 안 함").contains("강도:"))
    }
    func testLetterRemainsADraftAndPromptBoundsStaySafe() {
        let text = DeepMood.draft(prompt: 99, focus: "외로움", emotions: ["그리움"], contexts: ["연락"], intensity: 8, energy: "축 처짐")
        XCTAssertTrue(text.contains("이 편지를 보내지 않고")); XCTAssertTrue(text.contains("외로움"))
        XCTAssertEqual(DeepMind.prompts.count, DeepMind.templates.count)
    }
    func testUnknownThemeFallsBackWithoutInferringMood() {
        XCTAssertEqual(DeepMood.style("라일락"), "라일락")
        XCTAssertEqual(DeepMood.style("malformed"), "미드나잇")
    }
    func testReflectionIsOptionalBoundedAndNeverInventsAnswers() {
        var answers = Dictionary(uniqueKeysWithValues: DeepMood.reflectionLabels.map { ($0, String(repeating: "💜", count: 200)) })
        answers["injected"] = "unknown-field"
        let note = DeepMood.draft(prompt: 3, focus: "관계", emotions: ["불안"], contexts: ["연락"], intensity: 8, energy: "중간", reflection: answers)
        XCTAssertLessThanOrEqual(note.utf16.count, 2000)
        XCTAssertFalse(note.contains("unknown-field")); XCTAssertFalse(note.contains("�"))
        XCTAssertTrue(note.contains("지키고 싶은 선:"))
        let empty = DeepMood.draft(prompt: 0, focus: "자유롭게", emotions: [], contexts: [], intensity: nil, energy: "선택 안 함", reflection: [DeepMood.reflectionLabels[0]: "   "])
        XCTAssertFalse(empty.contains("[조금 더 깊이"))
        XCTAssertEqual(DeepMood.bounded(String(repeating: "a", count: 99) + "💜"), String(repeating: "a", count: 99))
    }
    func testReviewBoundsAndOptionalAfterIntensity() {
        var values = Dictionary(uniqueKeysWithValues: (DeepMood.reflectionLabels + DeepMood.reviewLabels).map { ($0, String(repeating: "💜", count: 200)) })
        values[DeepMood.afterKey] = "0"
        let text = DeepMood.draft(prompt: 3, focus: "관계", emotions: [], contexts: [], intensity: 8, energy: "중간", reflection: values)
        XCTAssertLessThanOrEqual(text.utf16.count, 2000); XCTAssertTrue(text.contains("돌아본 감정 강도: 0/10")); XCTAssertTrue(text.contains("[감정 전후 돌아보기]"))
        values[DeepMood.afterKey] = "11"; XCTAssertNil(DeepMood.answers(values)[DeepMood.afterKey])
        XCTAssertNil(DeepMood.answers(["unknown": "private"])["unknown"])
    }
    func testDraftSlotRoundTripFailureAndDeleteAreSeparateFromCurrentInput() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = [DeepMood.reviewLabels[0]: "산책", DeepMood.afterKey: "0"]
        try DeepDraftStore.save(current, directory: directory)
        XCTAssertEqual(try DeepDraftStore.load(directory: directory), current)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        try Data("invalid".utf8).write(to: DeepDraftStore.location(directory: directory))
        XCTAssertThrowsError(try DeepDraftStore.load(directory: directory)); XCTAssertEqual(current[DeepMood.reviewLabels[0]], "산책")
        try DeepDraftStore.remove(directory: directory); XCTAssertThrowsError(try DeepDraftStore.load(directory: directory))
    }
    func testShortWritingUsesValidatedFocusWithoutInjectingInput() {
        XCTAssertTrue(DeepMind.shortTemplate("외로움").contains("오늘 살펴볼 마음: 외로움"))
        XCTAssertFalse(DeepMind.shortTemplate("injected").contains("injected"))
        XCTAssertTrue(DeepMind.shortTemplate("관계").utf16.count < 500)
        XCTAssertNotEqual(DeepMind.starter("불안"), DeepMind.starter("외로움"))
    }
    func testRememberedTopicCannotIndexOutsideTemplates() {
        XCTAssertEqual(DeepMind.promptIndex(Int.min), 0)
        XCTAssertEqual(DeepMind.promptIndex(Int.max), DeepMind.prompts.count - 1)
        for n in -5...10 { XCTAssertFalse(DeepMind.templates[DeepMind.promptIndex(n)].isEmpty) }
    }
}
