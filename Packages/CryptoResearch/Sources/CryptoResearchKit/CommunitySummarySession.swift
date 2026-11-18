import SwiftUI

@MainActor final class CommunitySummarySession: ObservableObject {
    @Published private(set) var output = "선택한 공개 제목만 기기 안에서 요약합니다. 원문과 함께 확인하세요."
    @Published private(set) var busy = false
    @Published private(set) var canCopy = false
    private var revision = 0
    private var job: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    static func clean(_ titles: [String]) -> [String] {
        var seen = Set<String>()
        return titles.prefix(1000).compactMap { title in
            let text = String(title.precomposedStringWithCompatibilityMapping.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ").prefix(120))
            guard !text.isEmpty, seen.insert(text.lowercased()).inserted else { return nil }; return text
        }.prefix(12).map { $0 }
    }
    func cancel(_ message: String? = nil) {
        revision += 1; job?.cancel(); deadline?.cancel(); job = nil; deadline = nil; busy = false
        if let message { output = message; canCopy = false }
    }
    func start(_ titles: [String], timeout: UInt64 = 30_000_000_000, generate: @escaping ([String]) async throws -> String) {
        cancel(); let input = Self.clean(titles)
        guard !input.isEmpty else { output = "요약할 제목이 없습니다."; canCopy = false; return }
        let token = revision; busy = true; canCopy = false; output = "선택한 제목 \(input.count)개를 기기 안에서 요약하고 있습니다."
        job = Task { @MainActor [weak self] in
            do {
                let response = try await generate(input)
                guard let self, !Task.isCancelled, token == self.revision else { return }
                let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
                self.output = text.isEmpty ? "빈 응답입니다. 제목을 확인하고 다시 시도하세요." : "AI 생성 요약 · 원문 확인 필요\n" + String(text.prefix(1800))
                self.canCopy = !text.isEmpty
            } catch { guard let self, !Task.isCancelled, token == self.revision else { return }; self.output = "요약을 완료하지 못했습니다. 지원 상태를 확인하고 다시 시도하세요." }
            guard let self, token == self.revision else { return }; self.deadline?.cancel(); self.deadline = nil; self.job = nil; self.busy = false
        }
        deadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: timeout) } catch { return }
            guard let self, token == self.revision, self.busy else { return }
            self.cancel("30초 안에 완료하지 못해 중지했습니다. 다시 시도하거나 기존 제목 집계를 이용하세요.")
        }
    }
}
