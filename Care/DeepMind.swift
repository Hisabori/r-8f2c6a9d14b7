import SwiftUI

enum DeepMind {
    static let focuses = ["자유롭게", "불안", "외로움", "관계", "무기력", "스트레스"]
    static func focus(_ raw: String) -> String { focuses.contains(raw) ? raw : focuses[0] }
    static func template(_ index: Int, focus raw: String) -> String { let f = focus(raw); return (f == focuses[0] ? "" : "오늘 살펴볼 마음: " + f + "\n\n") + templates[min(templates.count-1,max(0,index))] }
    static func notificationTitle(mode: Bool, explicit: Bool) -> String { mode && explicit ? "시발 처먹어 ㅋㅋㅋㅋ" : mode ? "복용 시간 됐어. 일정 확인하자" : "복용 일정을 확인할 시간" }
    static func notificationBody(mode: Bool) -> String { mode ? "등록한 복용 일정이야. 이미 먹었는지 먼저 확인해. 먹었으면 추가로 먹지 마. 헷갈리면 약사에게 확인해." : "온케어에서 등록한 약과 복용 방법을 확인하세요." }
    static func promptIndex(_ raw: Int) -> Int { min(prompts.count - 1, max(0, raw)) }
    static func starter(_ raw: String) -> String {
        switch focus(raw) {
        case "불안": return "직접 확인한 일과, 아직 모르는 부분을 따로 적어볼까?"
        case "외로움": return "어떤 순간에 누군가와 연결되고 싶었어?"
        case "관계": return "그때 바랐던 말과 지키고 싶은 선은 뭐였어?"
        case "무기력": return "오늘 마음이나 몸이 무거웠던 순간이 있었어?"
        case "스트레스": return "오늘 네 에너지를 가장 많이 쓴 일은 뭐였어?"
        default: return "지금 남기고 싶은 한 장면은 뭐야?"
        }
    }
    static func shortTemplate(_ raw: String) -> String {
        "[짧게 남긴 마음]\n" + (focus(raw) == focuses[0] ? "" : "오늘 살펴볼 마음: " + focus(raw) + "\n") + "\n지금 내 말로 표현하면:\n\n몸에서 느껴지는 것:\n\n지금 원하는 도움 또는 쉬고 싶은 것:\n"
    }
    static let prompts = ["상황과 감정", "반복되는 생각", "상담 준비", "보내지 않을 편지"]
    static let templates = [
        "무슨 일이 있었나요?\n\n느낀 감정과 강도(내 표현으로):\n\n몸의 느낌:\n\n지금 필요한 것과 작은 행동:\n",
        "마음에 남은 생각:\n\n직접 확인한 사실:\n\n아직 모르는 부분:\n\n다른 가능성과 나에게 건넬 말:\n",
        "최근 가장 불편했던 점과 시작 시기:\n\n생활·수면에 미친 영향:\n\n도움이 됐거나 어려웠던 것:\n\n상담에서 물어볼 것:\n",
        "이 편지를 보내지 않고 여기 남기는 이유:\n\n정말 하고 싶었던 말:\n\n내가 바랐던 것과 지키고 싶은 선:\n\n지금 나를 위해 할 작은 일:\n"
    ]
    struct Summary { let days: Int; let average: Double?; let difficultDays: Int }
    static func summarize(_ entries: [Entry], now: Date = Date(), previous: Bool = false, calendar: Calendar = .current) -> Summary {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: previous ? -13 : -6, to: today)!
        let end = previous ? calendar.date(byAdding: .day, value: -6, to: today)! : now
        var latest: [Date: Entry] = [:]
        for e in entries where e.kind == "마음" && e.value.isFinite && (1...5).contains(e.value) && e.date >= start && (previous ? e.date < end : e.date <= end) {
            let day = calendar.startOfDay(for: e.date)
            if let old = latest[day], old.date > e.date || (old.date == e.date && old.id <= e.id) { continue }
            latest[day] = e
        }
        let values = latest.values.map(\.value)
        return Summary(days: values.count, average: values.isEmpty ? nil : values.reduce(0,+) / Double(values.count), difficultDays: values.filter { $0 <= 2 }.count)
    }
}

struct DeepMindCard: View {
    @EnvironmentObject var journal: Journal
    @State private var medication = false
    @State private var support = false
    @State private var draft: DeepMood.NoteDraft?
    @AppStorage("app-deep-style") private var style = "미드나잇"
    private var accent: Color { DeepMood.style(style) == "라일락" ? Color(red: 0.78, green: 0.69, blue: 1) : Color(red: 1, green: 0.73, blue: 0.82) }
    private var backdrop: Color { DeepMood.style(style) == "로즈" ? Color(red: 0.22, green: 0.08, blue: 0.16) : DeepMood.style(style) == "라일락" ? Color(red: 0.13, green: 0.09, blue: 0.22) : Color(red: 0.07, green: 0.05, blue: 0.10) }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            MedicationHomeCard { medication = true }
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("A LITTLE ROOM FOR YOU").font(.caption.weight(.semibold)).tracking(2); Spacer(); Image(systemName: "sparkle").accessibilityHidden(true) }.foregroundStyle(accent)
                Text("오늘의 마음을,\n천천히 펼쳐봐.").font(.system(.largeTitle, design: .rounded).bold()).accessibilityIdentifier("deep-mind-card")
                Text("말이 되지 않는 마음도 괜찮아. 한 줄부터 남겨봐.").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) { Image(systemName: "moon.stars").accessibilityHidden(true); Text("다 쓰지 않아도, 오늘의 한 줄이면 충분해.").font(.subheadline) }.foregroundStyle(accent).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            Picker("마음의 방 테마", selection: $style) { ForEach(DeepMood.styles, id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("deep-mood-style")
            DeepMoodComposer { note in draft = DeepMood.NoteDraft(note: note) }
            Divider().overlay(accent.opacity(0.3))
            Text("내가 남긴 두 주의 온도").font(.title3.bold())
            week("최근 7일", summary: DeepMind.summarize(journal.entries))
            week("그 이전 7일", summary: DeepMind.summarize(journal.entries, previous: true))
            Text("하루 마지막 직접 입력만 비교해. 기록 없는 날은 빼고, 1~2점 일수는 네가 힘들다고 남긴 날이야. 위험도나 진단은 아니야. 연동 마음 상태는 원본으로 따로 보관해.").font(.caption).foregroundStyle(.secondary)
            Button { support = true } label: { Label("혼자 정리하기 벅찰 땐 · 도움 보기", systemImage: "lifepreserver").frame(minHeight: 48) }.accessibilityIdentifier("deep-mind-support")
            Text("네 초안은 저장하기 전까지 기록이 아니야. 모드를 꺼도 저장한 일기는 남아. ChatGPT 개인 메모리를 자동으로 읽거나, 이 모드만으로 내용을 외부 전송하지 않아.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [backdrop, Color(red: 0.09, green: 0.07, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(accent.opacity(0.18), lineWidth: 1))
            .environment(\.colorScheme, .dark).foregroundStyle(.white).tint(accent)
            .sheet(item: $draft) { RecordView(kind: "마음", initialNote: $0.note) }
            .sheet(isPresented: $support) { CrisisSupportView() }.sheet(isPresented: $medication) { MedicationView() }
    }
    private func week(_ title: String, summary: DeepMind.Summary) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline).foregroundStyle(accent)
            Text(summary.average.map { number($0) + " / 5 · \(summary.days)일 기록 · 1~2점 \(summary.difficultDays)일" } ?? "기록 없음 · 추정하지 않아").font(.subheadline)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }
}
