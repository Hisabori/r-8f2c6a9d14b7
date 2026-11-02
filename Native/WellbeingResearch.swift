import SwiftUI
import CryptoResearchKit

struct WellbeingContext: Codable, Equatable {
    let sleepHours: Double?
    let sleepAt: Date?
    let moodValue: Double?
    let moodAt: Date?
    static func read(_ entries: [Entry], at now: Date) -> WellbeingContext {
        let eligible = entries.filter { $0.date <= now }
        let sleep = eligible.filter { $0.kind == "수면" && now.timeIntervalSince($0.date) <= 48*3600 && $0.value.isFinite && (0...24).contains($0.value) }.max { $0.date < $1.date }
        let mood = eligible.filter { $0.kind == "마음" && Calendar.current.isDate($0.date,inSameDayAs:now) && $0.value.isFinite }.max { $0.date < $1.date }
        return WellbeingContext(sleepHours:sleep?.value,sleepAt:sleep?.date,moodValue:mood?.value,moodAt:mood?.date)
    }
}
struct WellbeingResearchRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let condition: WellbeingContext
    let research: NativeResearchDigest
    let note: String
}

@MainActor final class WellbeingResearchStore: ObservableObject {
    @Published private(set) var records: [WellbeingResearchRecord] = []
    @Published var draft = ""
    @Published var notice: String?
    private let file: URL
    private var readable = true
    init(directory: URL? = nil) {
        let folder = directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("wellbeing-research",isDirectory:true)
        file = folder.appendingPathComponent("records-v1.json")
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            if FileManager.default.fileExists(atPath:file.path) {
                let handle = try FileHandle(forReadingFrom:file);defer { try? handle.close() }
                let data = try handle.read(upToCount:2*1024*1024+1) ?? Data()
                guard data.count <= 2*1024*1024 else { throw ResearchRecordError.invalid }
                records = try JSONDecoder().decode([WellbeingResearchRecord].self,from:data)
            }
        } catch { readable = false;notice = "함께 기록한 일기를 읽지 못해 저장을 멈췄습니다. 기존 파일은 보존했습니다." }
    }
    func save(condition: WellbeingContext,research: NativeResearchDigest?,consented: Bool,at now: Date = Date()) {
        guard consented else { notice = "건강 기록 함께 보기를 직접 켠 뒤 저장하세요.";return }
        guard readable,records.count < 500,let research,!research.synthetic,draft.count <= 2000 else { notice = "실제 분석 결과와 기록 길이를 확인하세요. 저장은 500개까지 지원합니다.";return }
        let row = WellbeingResearchRecord(id:UUID(),date:now,condition:condition,research:research,note:draft)
        do {
            var next = records;next.insert(row,at:0)
            let data = try JSONEncoder().encode(next)
            guard data.count <= 2*1024*1024 else { throw ResearchRecordError.invalid }
            try data.write(to:file,options:[.atomic,.completeFileProtection])
            records = next;draft = "";notice = "컨디션과 리서치 메모를 이 기기에 기록했습니다."
        } catch { notice = "저장하지 못했습니다. 기존 기록은 유지했습니다." }
    }
    private enum ResearchRecordError: Error { case invalid }
}

struct WellbeingResearchCard: View {
    @EnvironmentObject private var journal: Journal
    @EnvironmentObject private var investment: NativeInvestmentSession
    @EnvironmentObject private var store: WellbeingResearchStore
    @AppStorage("wellbeing-research-display-v1") private var enabled = false
    private var context: WellbeingContext { enabled ? WellbeingContext.read(journal.entries,at:Date()) : WellbeingContext(sleepHours:nil,sleepAt:nil,moodValue:nil,moodAt:nil) }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Label("컨디션과 리서치",systemImage:"heart.text.square").font(.title2.bold()).foregroundStyle(Palette.teal)
            Text("오늘의 나를 확인하고, 투자 생각도 차분하게 남겨요.").foregroundStyle(.secondary)
            Toggle("내 건강 기록 함께 보기",isOn:$enabled).accessibilityIdentifier("wellbeing-research-consent")
            if enabled {
                healthSummary(context)
                Divider()
                if let research = investment.researchDigest {
                    Text((research.synthetic ? "합성 예제 · ":"")+research.ticker+" · "+research.direction).font(.headline)
                    Text("분석 "+research.analyzedAt.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                } else { Text("아직 함께 볼 리서치가 없어요.").foregroundStyle(.secondary) }
                TextField("지금의 집중·감정과 투자 생각을 적어보세요",text:$store.draft,axis:.vertical).textFieldStyle(.roundedBorder).accessibilityIdentifier("wellbeing-research-note")
                Text("\(store.draft.count) / 2000자").font(.caption2).foregroundStyle(.secondary)
                Button("컨디션과 분석 함께 기록") { store.save(condition:context,research:investment.researchDigest,consented:enabled) }.disabled(investment.researchDigest == nil || investment.researchDigest?.synthetic == true || store.draft.count > 2000).frame(minHeight:44)
                if !store.records.isEmpty {
                    DisclosureGroup("함께 남긴 기록 \(store.records.count)개") {
                        ForEach(store.records.prefix(5)) { record in
                            VStack(alignment:.leading,spacing:6) {
                                Text(record.date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                                Text(record.research.ticker+" · "+record.research.direction).font(.headline)
                                healthSummary(record.condition)
                                if !record.note.isEmpty { Text(record.note) }
                            }.padding(.vertical,8)
                        }
                    }
                    NavigationLink("함께 남긴 기록 전체 보기") { WellbeingResearchHistory() }.frame(minHeight:44)
                }
            }
            NavigationLink { TickerResearchView().toolbar(.hidden,for:.tabBar) } label: { Label("컨디션 확인 후 티커 살펴보기",systemImage:"chart.xyaxis.line").frame(minHeight:44) }.accessibilityIdentifier("wellbeing-ticker-open")
            Text("선택한 건강 요약과 메모는 기기에만 보관해요. 건강 값으로 종목 점수·주문을 바꾸거나 수익률을 예측하지 않습니다. 표시를 꺼도 이미 저장한 개인 메모는 기기에 남습니다.").font(.caption).foregroundStyle(.secondary)
        }.careCard()
        .alert("함께 기록하기",isPresented:Binding(get:{ store.notice != nil },set:{ if !$0 { store.notice = nil } })) { Button("확인") { store.notice = nil } } message: { Text(store.notice ?? "") }
    }
    private func healthSummary(_ context: WellbeingContext) -> some View {
        VStack(alignment:.leading,spacing:7) {
            if let hours = context.sleepHours,let date = context.sleepAt {
                Text("최근 수면 기록 \(number(hours))시간 · "+date.formatted(date:.abbreviated,time:.shortened))
            } else { Text("48시간 이내 수면 기록 없음").foregroundStyle(.secondary) }
            if let mood = context.moodValue { Text("오늘 마음 기록 \(number(mood)) \(unit("마음"))") }
            else { Text("오늘 마음 기록 없음").foregroundStyle(.secondary) }
        }.font(.subheadline)
    }
}

private struct WellbeingResearchHistory: View {
    @EnvironmentObject private var store: WellbeingResearchStore
    @AppStorage("wellbeing-research-display-v1") private var enabled = false
    var body: some View {
        List {
            if enabled {
                ForEach(store.records) { record in
                    VStack(alignment:.leading,spacing:8) {
                        Text(record.date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                        Text(record.research.ticker+" · "+record.research.direction).font(.headline)
                        if let hours = record.condition.sleepHours { Text("수면 기록 \(number(hours))시간") }
                        if let mood = record.condition.moodValue { Text("마음 기록 \(number(mood)) \(unit("마음"))") }
                        if !record.note.isEmpty { Text(record.note) }
                    }.padding(.vertical,6)
                }
            } else { Text("홈에서 건강 기록 함께 보기를 켜면 개인 메모를 볼 수 있어요.") }
        }.navigationTitle("컨디션과 리서치 기록").navigationBarTitleDisplayMode(.inline)
    }
}
