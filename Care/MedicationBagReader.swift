import SwiftUI
import PhotosUI
import Vision
import ImageIO

enum MedicationBagText {
    static func lines(_ text: String) -> [String] {
        Array(text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(100)).map { String($0.prefix(500)) }
    }
    struct Candidates { var names: [String] = []; var instructions: [String] = [] }
    private static let phone = try! NSRegularExpression(pattern: #"\d{2,4}[- ]\d{3,4}[- ]\d{4}"#)
    private static let drug = try! NSRegularExpression(pattern: #"[가-힣a-z][가-힣a-z0-9 .·()-]*(정|캡슐|시럽|산|액|mg|mcg|밀리그램)(\s|\d|$)"#)
    private static let privateTerms = ["환자", "성명", "생년", "주민", "전화", "주소", "면허", "사업자", "처방전번호"]
    private static let methodTerms = ["식전", "식후", "식사", "취침", "복용", "하루", "매일", "아침", "점심", "저녁", "1일", "회분"]
    static func analyze(_ rows: [String]) -> Candidates {
        var result = Candidates(); var seen = Set<String>()
        for line in rows {
            let value = line.precomposedStringWithCompatibilityMapping.lowercased()
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            guard !seen.contains(value), !privateTerms.contains(where: value.contains), !value.contains("@"), phone.firstMatch(in: value, range: range) == nil else { continue }
            if methodTerms.contains(where: value.contains) { result.instructions.append(line); seen.insert(value) }
            else if drug.firstMatch(in: value, range: range) != nil { result.names.append(line); seen.insert(value) }
        }
        return result
    }
    static func candidates(_ text: String, instructions: Bool) -> [String] {
        let result = analyze(lines(text)); return instructions ? result.instructions : result.names
    }
    static func append(_ line: String, to current: String) -> String? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return current }
        if lines(current).contains(value) { return current }
        let result = current.isEmpty ? value : current + "\n" + value
        return result.count <= 200 ? result : nil
    }
    static func importedText(_ text: String) -> String? {
        guard text.utf16.count <= 12000, !text.contains("\0") else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = value.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !value.isEmpty, rows.count <= 100, rows.allSatisfy({ $0.utf16.count <= 500 }) else { return nil }
        return value
    }
    static func recognize(_ data: Data) throws -> String {
        guard data.count <= 20 * 1024 * 1024, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw CareError.invalid }
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["ko-KR", "en-US"].filter { supported.contains($0) }
        guard request.recognitionLanguages.contains("ko-KR") else { throw CareError.invalid }
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
struct MedicationBagReader: View {
    var textOnly = false
    let apply: (String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var textFocused: Bool
    @State private var rawText = ""
    @State private var textReviewed = false
    @State private var photo: PhotosPickerItem?
    @State private var lines: [String] = []
    @State private var candidateGroups = MedicationBagText.Candidates()
    @State private var busy = false
    @State private var message = ""
    @State private var query = ""
    @State private var name = ""
    @State private var instructions = ""
    private var filtered: [String] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? lines : lines.filter { $0.localizedCaseInsensitiveContains(value) }
    }
    private func appendInstruction(_ line: String) {
        if let updated = MedicationBagText.append(line, to: instructions) { instructions = updated; message = "" }
        else { message = "복용 안내가 200자를 넘어요. 기존 내용은 유지했어요. 필요한 내용을 직접 정리해주세요." }
    }
    private var textImportSection: some View {
                Section("문자 복약 안내 가져오기") {
                    Text("문자 앱에서 필요한 내용을 복사한 뒤 붙여넣어주세요. 문자함 전체를 읽지 않으며, 원문은 투약 기록에 저장하지 않아요.").font(.subheadline).foregroundStyle(.secondary)
                    if !textReviewed {
                    PasteButton(payloadType: String.self) { values in Task { @MainActor in if values.count == 1, let value = values.first, MedicationBagText.importedText(value) != nil { rawText = value; message = "" } else { message = "한 개의 문자 내용을 선택해주세요. 최대 12,000자·100줄·한 줄 500자까지 가져올 수 있어요." } } }.accessibilityIdentifier("medication-text-paste")
                    TextEditor(text: $rawText).focused($textFocused).frame(minHeight: 140).accessibilityIdentifier("medication-text-input")
                    Button("내용에서 사용할 줄 고르기") {
                        guard let text = MedicationBagText.importedText(rawText) else { message = "내용이 비어 있거나 입력 한도를 넘었어요. 필요한 안내만 남겨주세요."; return }
                        lines = MedicationBagText.lines(text); name = ""; instructions = ""; message = ""; textFocused = false; textReviewed = true
                    }.accessibilityIdentifier("medication-text-review")
                    Text("이름·연락처·인증번호 등 불필요한 내용은 지워주세요. 약 이름과 복용 안내를 직접 확인한 뒤 필요한 줄만 적용해요.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(lines.count)개 줄을 가져왔어요. 아래에서 필요한 내용만 선택해주세요.").accessibilityIdentifier("medication-text-lines-count")
                        Button("원문 다시 편집") { textReviewed = false }.accessibilityIdentifier("medication-text-edit")
                    }
                    if !message.isEmpty { Text(message).foregroundStyle(Palette.coral) }
                }
    }
    var body: some View {
        NavigationStack { List {
            if !textOnly { Section { Text("약봉지를 밝은 곳에서 똑바로 촬영한 사진을 골라주세요. 환자 이름 등 개인정보가 있는 줄은 입력하지 마세요. 사진과 인식 원문은 투약 기록에 보관하지 않습니다.").font(.subheadline).foregroundStyle(.secondary)
                PhotosPicker(selection: $photo, matching: .images) { Label("약봉지 사진 선택", systemImage: "photo") }.disabled(busy).accessibilityIdentifier("medication-ocr-photo")
                if busy { ProgressView("글자를 읽고 있어요") }; if !message.isEmpty { Text(message).foregroundStyle(Palette.coral) }
            }
            }
            if textOnly { textImportSection }
            Section("입력 전 확인") { TextField("약 이름 · 선택한 줄을 수정하세요", text: $name).accessibilityIdentifier("ocr-name-preview"); Text("\(name.count) / 80자").font(.caption).foregroundStyle(name.count > 80 ? Palette.coral : .secondary); TextField("복용 방법 · 선택한 줄을 수정하세요", text: $instructions, axis: .vertical).accessibilityIdentifier("ocr-instructions-preview"); Text("\(instructions.count) / 200자").font(.caption).foregroundStyle(instructions.count > 200 ? Palette.coral : .secondary); if name.count > 80 || instructions.count > 200 { Text("긴 문장은 자동으로 잘라 넣지 않아요. 필요한 내용을 직접 줄여주세요.").font(.caption).foregroundStyle(Palette.coral) }; Button("확인한 내용으로 입력 화면에 적용") { if !name.isEmpty { apply(name, true) }; if !instructions.isEmpty { apply(instructions, false) }; dismiss() }.disabled((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || name.count > 80 || instructions.count > 200 || (textOnly && lines.isEmpty)).accessibilityIdentifier("medication-ocr-apply") }
            if !lines.isEmpty {
                Section("약 이름 후보 · 원본 확인 필요") { ForEach(candidateGroups.names, id: \.self) { line in Button(line) { name = line } } }
                Section("복용 안내 후보 · 원본 확인 필요") { ForEach(candidateGroups.instructions, id: \.self) { line in Button("추가 · " + line) { appendInstruction(line) } } }
            }
            Section("인식한 줄 · 직접 선택") { TextField("인식한 글자 검색", text: $query).accessibilityIdentifier("ocr-line-search"); Text("\(filtered.count) / \(lines.count)개 줄").font(.caption).foregroundStyle(.secondary); ForEach(Array(filtered.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 10) { Text(line).textSelection(.enabled)
                    HStack { Button("약 이름에 사용") { name = line }; Spacer(); Button("복용 방법에 추가") { appendInstruction(line) } }.font(.caption)
                }.padding(.vertical, 4)
            } }
            Section { Text("인식 오류가 있을 수 있어요. 용량·시간·요일은 자동으로 정하지 않으며 알림은 꺼진 상태로 돌아갑니다. 원본을 확인한 뒤 일정을 직접 저장하세요.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle(textOnly ? "문자 복약 안내" : "약봉지 글자 인식").navigationBarTitleDisplayMode(.inline).modifier(CareThemeSurface()).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("닫기") { dismiss() } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("입력 완료") { textFocused = false }.accessibilityIdentifier("medication-text-done") } }
        .onChange(of: lines) { candidateGroups = MedicationBagText.analyze($0) }
        .onChange(of: rawText) { _ in lines = []; name = ""; instructions = ""; textReviewed = false }
        .task(id: photo) {
            guard let selected = photo else { return }; busy = true; lines = []; name = ""; instructions = ""; message = ""; query = ""
            do { guard let data = try await selected.loadTransferable(type: Data.self) else { throw CareError.invalid }
                let text = try await Task.detached(priority: .userInitiated) { try MedicationBagText.recognize(data) }.value
                guard !Task.isCancelled else { return }; lines = MedicationBagText.lines(text); if lines.isEmpty { message = "읽을 수 있는 글자가 없어요. 선명한 사진을 다시 선택해주세요." }
            } catch { if !Task.isCancelled { message = "사진을 읽지 못했어요. 20MB 이하의 선명한 사진인지 확인해주세요." } }
            busy = false
        }
        }
    }
}
