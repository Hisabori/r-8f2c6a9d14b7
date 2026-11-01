import SwiftUI

enum DeepMood {
    struct NoteDraft: Identifiable { let id = UUID(); let note: String }
    static let styles = ["미드나잇", "로즈", "라일락"]
    static let emotions = ["불안", "서운함", "외로움", "질투", "분노", "공허함", "지침", "슬픔", "그리움", "안도", "설렘", "편안함"]
    static let contexts = ["연락", "관계", "혼자 있는 시간", "일·공부", "수면", "몸 상태", "이유 모름"]
    static let energies = ["선택 안 함", "축 처짐", "중간", "들뜸·긴장"]
    static let reflectionLabels = ["실제로 있었던 일", "머릿속에서 붙인 의미", "몸에서 느껴진 것", "정말 바랐던 것", "지키고 싶은 선", "지금 할 수 있는 작은 일"]
    static let reviewLabels = ["해본 행동", "도움이 된 점 · 어려웠던 점", "다음에 기억할 것"]
    static let afterKey = "돌아본 감정 강도"
    static func answers(_ values: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for key in reflectionLabels + reviewLabels {
            let value = bounded(values[key] ?? "")
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result[key] = value }
        }
        if let raw = values[afterKey], let value = Int(raw), (0...10).contains(value) { result[afterKey] = String(value) }
        return result
    }
    static func bounded(_ text: String) -> String {
        var units = Array(text.utf16.prefix(100))
        if let last = units.last, (0xD800...0xDBFF).contains(last) { units.removeLast() }
        return String(decoding: units, as: UTF16.self)
    }
    static func style(_ raw: String) -> String { styles.contains(raw) ? raw : styles[0] }
    static func draft(prompt: Int, focus: String, emotions chosen: Set<String>, contexts context: Set<String>, intensity: Int?, energy: String, reflection: [String: String] = [:]) -> String {
        let feelings = emotions.filter { chosen.contains($0) }.prefix(3)
        let situations = contexts.filter { context.contains($0) }.prefix(2)
        var lines = ["[내 마음 캡슐]"]
        if !feelings.isEmpty { lines.append("섞인 감정: " + feelings.joined(separator: " · ")) }
        if !situations.isEmpty { lines.append("마음이 움직인 상황: " + situations.joined(separator: " · ")) }
        if let n = intensity, (0...10).contains(n) { lines.append("내가 고른 강도: \(n)/10 (0 아주 약함 · 10 아주 강함)") }
        if energies.dropFirst().contains(energy) { lines.append("지금 에너지: " + energy) }
        let detail = reflectionLabels.compactMap { label -> String? in
            let answer = bounded(reflection[label] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : label + ": " + answer
        }
        if !detail.isEmpty { lines.append("\n[조금 더 깊이, 내 말로]\n" + detail.joined(separator: "\n")) }
        let review = reviewLabels.compactMap { label -> String? in
            let answer = bounded(reflection[label] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : label + ": " + answer
        }
        if !review.isEmpty { lines.append("\n[감정 전후 돌아보기]\n" + review.joined(separator: "\n")) }
        if let after = answers(reflection)[afterKey] { lines.append("돌아본 감정 강도: " + after + "/10 · 내가 직접 남긴 표현") }
        lines.append("\n" + DeepMind.template(prompt, focus: focus))
        return lines.joined(separator: "\n")
    }
}

struct DeepMoodComposer: View {
    let write: (String) -> Void
    @AppStorage("app-deep-focus") private var focus = "자유롭게"
    @AppStorage("app-deep-prompt-v1") private var storedPrompt = 0
    private var prompt: Int { DeepMind.promptIndex(storedPrompt) }
    @State private var feelings = Set<String>()
    @State private var contexts = Set<String>()
    @State private var intensity = 5.0
    @State private var useIntensity = false
    @State private var energy = "선택 안 함"
    @State private var reflection: [String: String] = [:]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(DeepMind.starter(focus)).font(.headline).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("deep-focus-question")
            Button("말이 안 나올 땐 · 짧게 기록") { write(DeepMind.shortTemplate(focus)) }.frame(minHeight: 48).accessibilityIdentifier("deep-short-write")
            Text("선택·속사정을 넣지 않은 새 짧은 양식을 열어. 저장은 다음 화면에서 네가 결정해.").font(.caption).foregroundStyle(.secondary)
            Text("마음은 하나만 고를 필요 없어").font(.title3.bold())
            Text("지금 섞여 있는 감정, 최대 3개만 골라봐.").font(.subheadline).foregroundStyle(.secondary)
            chips(DeepMood.emotions, selected: $feelings, limit: 3, prefix: "emotion")
            Text("어떤 순간이었어? · 최대 2개").font(.headline)
            chips(DeepMood.contexts, selected: $contexts, limit: 2, prefix: "context")
            Toggle("감정 강도도 남길래", isOn: $useIntensity).accessibilityIdentifier("deep-mood-intensity-toggle")
            if useIntensity {
                Text("\(Int(intensity))/10 · 0 아주 약함 → 10 아주 강함").font(.subheadline).monospacedDigit()
                Slider(value: $intensity, in: 0...10, step: 1).accessibilityLabel("감정 강도").accessibilityIdentifier("deep-mood-intensity")
            }
            Text("지금 에너지").font(.headline)
            Picker("지금 에너지", selection: $energy) { ForEach(DeepMood.energies, id: \.self) { Text($0).tag($0) } }
            Text("오늘 더 들여다볼 마음").font(.headline)
            Picker("오늘 더 들여다볼 마음", selection: $focus) { ForEach(DeepMind.focuses, id: \.self) { Text($0).tag($0) } }
            DeepReflectionFields(reflection: $reflection)
            DeepReviewFields(reflection: $reflection)
            Text("어디까지 써볼까").font(.headline)
            Picker("어디까지 써볼까", selection: Binding(get: { prompt }, set: { storedPrompt = DeepMind.promptIndex($0) })) { ForEach(0..<DeepMind.prompts.count, id: \.self) { Text(DeepMind.prompts[$0]).tag($0) } }.accessibilityIdentifier("deep-mind-prompt")
            Text("선택한 기록 주제만 이 기기에 기억해. 본문을 이어 쓰려면 위의 임시보관 버튼으로 남겨둬.").font(.caption).foregroundStyle(.secondary)
            Text(DeepMind.templates[prompt]).font(.subheadline).foregroundStyle(.secondary)
            Button { write(DeepMood.draft(prompt: prompt, focus: focus, emotions: feelings, contexts: contexts, intensity: useIntensity ? Int(intensity) : nil, energy: energy, reflection: reflection)) } label: {
                Label("마음 캡슐 열고 일기 쓰기", systemImage: "heart.text.square.fill").font(.headline).foregroundStyle(Color.black).frame(maxWidth: .infinity).padding(.vertical, 16)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("deep-mind-write")
            Text("선택은 초안이야. 다음 화면에서 고치고 저장해야 기록돼. 강도는 네 표현이고, 건강 점수로 환산하지 않아.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func chips(_ choices: [String], selected: Binding<Set<String>>, limit: Int, prefix: String) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(choices, id: \.self) { item in
                let on = selected.wrappedValue.contains(item)
                Button {
                    if on { selected.wrappedValue.remove(item) } else if selected.wrappedValue.count < limit { selected.wrappedValue.insert(item) }
                } label: { HStack { Text(item); Spacer(); Image(systemName: on ? "checkmark.circle.fill" : "circle") }.font(.subheadline.weight(.medium)).padding(12).frame(minHeight: 48).background(on ? Color.pink.opacity(0.15) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? Color.pink.opacity(0.6) : Color.white.opacity(0.10))) }
                .buttonStyle(.plain).disabled(!on && selected.wrappedValue.count >= limit).accessibilityLabel(item).accessibilityValue(on ? "선택됨" : "선택 안 됨").accessibilityIdentifier("deep-mood-\(prefix)-\(item)")
            }
        }
    }
}

struct DeepReflectionFields: View {
    @Binding var reflection: [String: String]
    var body: some View {
            DisclosureGroup("조금 더 깊이 · 마음의 속사정") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("사실과 해석을 따로 놓고, 네가 바랐던 것까지 적어봐. 빈칸은 남겨도 돼. 각 항목은 100자까지야.").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(DeepMood.reflectionLabels.enumerated()), id: \.offset) { index, label in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label).font(.subheadline.bold())
                            TextField("네 말로, 짧게 적어도 돼", text: Binding(get: { reflection[label] ?? "" }, set: { reflection[label] = DeepMood.bounded($0) }), axis: .vertical)
                                .lineLimit(2...4).padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.10))).accessibilityIdentifier("deep-reflection-\(index)")
                        }
                    }
                    Button("지금 쓴 속사정 비우기") { for key in DeepMood.reflectionLabels { reflection.removeValue(forKey: key) } }.accessibilityIdentifier("deep-reflection-clear")
                    Text("일기 초안으로만 이어져. 다음 화면에서 저장해야 기록돼. 앱을 종료하면 저장 전 내용은 사라질 수 있어.").font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 8)
            }.toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("입력 마침") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("deep-reflection-done")
                }
            }
    }
}
