import SwiftUI

/// Explicit local draft slot; excluded from backup and separate from saved journal records.
enum DeepDraftStore {
    static func location(directory: URL? = nil) throws -> URL {
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OnCareDrafts", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var target = folder; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        return folder.appendingPathComponent("mind-capsule.json")
    }
    static func save(_ values: [String: String], directory: URL? = nil) throws {
        let data = try JSONEncoder().encode(DeepMood.answers(values))
        guard data.count <= 32768 else { throw CareError.invalid }
        try data.write(to: location(directory: directory), options: [.atomic, .completeFileProtection])
    }
    static func load(directory: URL? = nil) throws -> [String: String] {
        let url = try location(directory: directory)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 32769
        guard size <= 32768 else { throw CareError.invalid }
        let data = try Data(contentsOf: url)
        return DeepMood.answers(try JSONDecoder().decode([String: String].self, from: data))
    }
    static func remove(directory: URL? = nil) throws {
        let url = try location(directory: directory)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
struct DeepReviewFields: View {
    @Binding var reflection: [String: String]
    @State private var status = ""
    @State private var restore = false
    @State private var deleting = false
    var body: some View {
        DisclosureGroup("감정 전후 돌아보기 · 임시보관") {
            VStack(alignment: .leading, spacing: 12) {
                Text("행동 뒤 느낌을 남겨봐. 그대로거나 더 힘들어도 네 표현 그대로야. 강도 차이를 치료 효과나 건강 점수로 계산하지 않아.").font(.caption).foregroundStyle(.secondary)
                Toggle("지금의 강도도 남길래", isOn: Binding(get: { reflection[DeepMood.afterKey] != nil }, set: { reflection[DeepMood.afterKey] = $0 ? "5" : nil })).accessibilityIdentifier("deep-review-intensity-toggle")
                if let raw = reflection[DeepMood.afterKey], let value = Int(raw) {
                    Text("지금 \(value)/10 · 0 아주 약함 → 10 아주 강함")
                    Slider(value: Binding(get: { Double(reflection[DeepMood.afterKey] ?? "5") ?? 5 }, set: { reflection[DeepMood.afterKey] = String(Int($0)) }), in: 0...10, step: 1).accessibilityIdentifier("deep-review-intensity")
                }
                ForEach(Array(DeepMood.reviewLabels.enumerated()), id: \.offset) { index, label in
                    Text(label).font(.subheadline.bold())
                    TextField("네 말로 남겨봐 · 100자까지", text: Binding(get: { reflection[label] ?? "" }, set: { reflection[label] = DeepMood.bounded($0) }), axis: .vertical).lineLimit(2...4).padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.10))).accessibilityIdentifier("deep-review-\(index)")
                }
                Button("속사정·돌아보기 글 임시보관") { do { try DeepDraftStore.save(reflection); status = "이 기기에 한 건 임시보관했어. 일기 저장과는 달라." } catch { status = "임시보관하지 못했어. 지금 입력은 유지돼." } }.accessibilityIdentifier("deep-draft-save")
                Button("임시보관 이어 쓰기") { restore = true }.accessibilityIdentifier("deep-draft-restore")
                Button("보관한 초안 삭제", role: .destructive) { deleting = true }.accessibilityIdentifier("deep-draft-delete")
                if !status.isEmpty { Text(status).font(.caption).accessibilityIdentifier("deep-draft-status") }
                Text("보관 버튼을 누를 때만 이 기기에 한 건 저장해. 감정·상황 선택과 처음 강도는 보관하지 않아. 일기를 저장해도 보관본은 남으니 필요 없으면 삭제해. 일반 백업·기기 간 동기화에는 넣지 않아.").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 8)
        }
        .confirmationDialog("지금 쓴 속사정·돌아보기를 보관본으로 바꿀까?", isPresented: $restore, titleVisibility: .visible) {
            Button("보관본 불러오기") { do { reflection = try DeepDraftStore.load(); status = "보관본을 불러왔어. 일기로 남기려면 다음 화면에서 저장해." } catch { status = "불러올 보관본이 없거나 읽지 못했어. 지금 입력은 유지돼." } }
        }
        .confirmationDialog("이 기기에 보관한 초안 한 건을 삭제할까?", isPresented: $deleting, titleVisibility: .visible) {
            Button("보관본 삭제", role: .destructive) { do { try DeepDraftStore.remove(); status = "보관본만 삭제했어. 지금 입력과 저장된 일기는 유지돼." } catch { status = "보관본을 삭제하지 못했어." } }
        }
    }
}
