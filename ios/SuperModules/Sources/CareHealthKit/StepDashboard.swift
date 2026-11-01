import SwiftUI
import Combine
import HealthKit
import Charts

struct StepTotal: Codable, Identifiable, Equatable {
    var day: String
    var count: Int
    var id: String { day }
}
enum StepTotals {
    static func valid(_ rows: [StepTotal], now: Date = Date()) -> [StepTotal] {
        let allowed = Set((0..<7).map { dateKey(dayOffset(-$0, from: now)) })
        var result: [String: StepTotal] = [:]
        for row in rows where allowed.contains(row.day) && (0...1_000_000).contains(row.count) { result[row.day] = row }
        return result.values.sorted { $0.day < $1.day }
    }
    static func difference(_ rows: [StepTotal], now: Date = Date()) -> Int? {
        let values = valid(rows, now: now)
        guard let today = values.first(where: { $0.day == dateKey(now) })?.count, let yesterday = values.first(where: { $0.day == dateKey(dayOffset(-1, from: now)) })?.count else { return nil }
        return today - yesterday
    }
    static func merge(_ old: [StepTotal], _ fresh: [StepTotal], now: Date = Date()) -> [StepTotal] { valid(valid(old, now: now) + valid(fresh, now: now), now: now) }
    static func overview(_ entries: [Entry], now: Date = Date()) -> [SummaryDay] {
        let source = UserDefaults.standard.string(forKey: "step-source-v1") ?? "apple"
        var rows: [StepTotal] = []
        if source == "apple", let data = UserDefaults.standard.data(forKey: "steps-daily-v1"), let saved = try? JSONDecoder().decode([StepTotal].self, from: data) { rows = valid(saved, now: now) }
        else if source != "apple" { rows = linked(entries, source: source, now: now) }
        return (0..<7).map { offset in let day = dayOffset(offset - 6, from: now); return SummaryDay(date: day, value: rows.first { $0.day == dateKey(day) }.map { Double($0.count) }) }
    }
    static func goal(_ raw: Int) -> Int { min(30_000, max(1_000, raw / 500 * 500)) }
    static func linked(_ entries: [Entry], source: String, now: Date = Date()) -> [StepTotal] {
        var latest: [String: Entry] = [:]
        for e in entries where e.kind == "걸음" && e.source == source && e.date <= now && e.value.isFinite && e.value >= 0 && e.value <= 1_000_000 && e.value.rounded() == e.value {
            let key = dateKey(e.date)
            if let old = latest[key], old.date > e.date || (old.date == e.date && old.id >= e.id) { continue }
            latest[key] = e
        }
        return valid(latest.map { StepTotal(day: $0.key, count: Int($0.value.value)) }, now: now)
    }
}
@MainActor final class StepHealthStore: ObservableObject {
    @Published var rows: [StepTotal] = []
    @Published var busy = false
    @Published var status = "Apple 건강에서 최근 7일의 일별 걸음을 읽어요."
    @Published var refreshed: Date?
    private let health = HKHealthStore()
    private var epoch = 0
    init() {
        if let data = UserDefaults.standard.data(forKey: "steps-daily-v1"), let saved = try? JSONDecoder().decode([StepTotal].self, from: data) { rows = StepTotals.valid(saved) }
        refreshed = UserDefaults.standard.object(forKey: "steps-refreshed-v1") as? Date
    }
    func cancel() { epoch += 1; busy = false }
    func refresh(authorize: Bool) async {
        guard !busy else { return }
        guard HKHealthStore.isHealthDataAvailable(), let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { status = "Apple 건강을 사용할 수 없어요."; return }
        epoch += 1; let request = epoch; busy = true
        defer { if request == epoch { busy = false } }
        do {
            if authorize { try await health.requestAuthorization(toShare: [], read: [type]) }
            guard request == epoch else { return }
            let now = Date(), start = dayOffset(-6)
            let fresh: [StepTotal] = try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: now), options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
                query.initialResultsHandler = { _, collection, error in
                    if let error { continuation.resume(throwing: error); return }
                    var result: [StepTotal] = []
                    collection?.enumerateStatistics(from: start, to: now) { item, _ in
                        if let quantity = item.sumQuantity() {
                            let value = quantity.doubleValue(for: .count())
                            if value.isFinite, value >= 0, value <= 1_000_000, value.rounded() == value { result.append(StepTotal(day: dateKey(item.startDate), count: Int(value))) }
                        }
                    }
                    continuation.resume(returning: result)
                }
                health.execute(query)
            }
            guard request == epoch else { return }
            guard !fresh.isEmpty else { status = "읽을 수 있는 걸음이 없어요. 기록 없음과 권한 제한은 구별할 수 없어 기존 값을 유지했어요."; return }
            let next = StepTotals.merge(rows, fresh, now: now)
            UserDefaults.standard.set(try JSONEncoder().encode(next), forKey: "steps-daily-v1")
            UserDefaults.standard.set(now, forKey: "steps-refreshed-v1")
            rows = next; refreshed = now; UserDefaults.standard.set(UUID().uuidString, forKey: "steps-cache-token-v1")
            status = "\(fresh.count)일 집계를 읽었어요. 결과가 없는 날짜는 기존 보관값을 유지해요."
        } catch { if request == epoch { status = "읽지 못했어요. 건강 읽기 권한과 HealthKit 서명을 확인해주세요. 기존 값은 유지했어요." } }
    }
    func clear() { cancel(); rows = []; refreshed = nil; UserDefaults.standard.removeObject(forKey: "steps-daily-v1"); UserDefaults.standard.removeObject(forKey: "steps-refreshed-v1"); UserDefaults.standard.set(UUID().uuidString, forKey: "steps-cache-token-v1"); status = "Apple 걸음 보관값만 지웠어요." }
}
struct StepDashboard: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var health = StepHealthStore()
    @AppStorage("step-goal-v1") private var goal = 8_000
    @AppStorage("step-source-v1") private var source = "apple"
    @AppStorage("steps-live-v1") private var liveEnabled = false
    @StateObject private var live = ProgressLiveStatus.shared
    @State private var deleting = false
    private var sources: [String] { Array(Set(journal.entries.filter { $0.kind == "걸음" && $0.source?.hasPrefix("health-connect:") == true }.compactMap(\.source))).sorted() }
    private var rows: [StepTotal] { source == "apple" ? StepTotals.valid(health.rows) : StepTotals.linked(journal.entries, source: source) }
    private var today: Int? { rows.first { $0.day == dateKey(Date()) }?.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                todayCard
                controls
                history
                if source == "apple" { connection }
                else { Text("Android에서 걸음을 읽고 기기 간 동기화해주세요. 마지막으로 받은 기록이며 실시간 값이 아닙니다.").font(.caption) }
                NavigationLink("건강 데이터 연결 관리") { HealthConnectionView() }
            }.padding(22)
        }.background(CareAppearance.background).navigationTitle("만보기").navigationBarTitleDisplayMode(.inline).modifier(CareThemeSurface())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .onDisappear { health.cancel() }.onChange(of: phase) { if $0 == .background { health.cancel() } }
            .onAppear { if source != "apple" && !sources.contains(source) { source = "apple" }; syncLive() }
            .onChange(of: today) { _ in syncLive() }.onChange(of: goal) { _ in syncLive() }.onChange(of: source) { _ in syncLive() }.onChange(of: liveEnabled) { _ in syncLive() }
            .confirmationDialog("Apple 걸음 보관값을 지울까요?", isPresented: $deleting) { Button("보관값 지우기", role: .destructive) { health.clear() } } message: { Text("목표·일기·Apple 건강 원본·Android 연결 기록은 유지됩니다.") }
    }
    private func syncLive() {
        guard #available(iOS 16.2, *) else { return }
        live.sync(kind: .steps, sessionID: dateKey(Date()), value: today, goal: StepTotals.goal(goal), beganAt: Calendar.current.startOfDay(for: Date()), enabled: liveEnabled)
    }
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("오늘의 작은 발걸음", systemImage: "figure.walk").font(.headline).foregroundStyle(.orange)
            Text(today.map { $0.formatted() } ?? "—").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().accessibilityIdentifier("steps-today")
            Text(today.map { $0 >= StepTotals.goal(goal) ? "오늘 정한 목표에 닿았어요. 편안하게 쉬어가도 좋아요." : "목표까지 \(max(0, StepTotals.goal(goal) - $0).formatted())걸음 남았어요." } ?? "오늘 데이터가 아직 없어요. 0걸음으로 추정하지 않아요.").font(.subheadline)
            if let difference = StepTotals.difference(rows) {
                Text("오늘 현재까지 − 어제 하루: " + (difference > 0 ? "+" : "") + difference.formatted() + "걸음").font(.subheadline).accessibilityIdentifier("steps-comparison")
            } else { Text("어제와 오늘 기록이 모두 있을 때 비교해요.").font(.caption).foregroundStyle(.secondary) }
            ProgressView(value: min(1, Double(today ?? 0) / Double(StepTotals.goal(goal)))).tint(.orange)
            Text("내 목표 \(StepTotals.goal(goal).formatted())걸음 · 현재까지 읽은 집계").font(.caption).foregroundStyle(.secondary)
        }.careCard()
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("나에게 맞는 하루 목표").font(.headline)
            Stepper("\(StepTotals.goal(goal).formatted())걸음", value: Binding(get: { StepTotals.goal(goal) }, set: { goal = $0 }), in: 1_000...30_000, step: 500).accessibilityIdentifier("steps-goal")
            Text("개인 목표예요. 만보를 꼭 채울 필요는 없어요.").font(.caption).foregroundStyle(.secondary)
            Picker("표시할 출처", selection: $source) { Text("Apple 건강 일별 집계").tag("apple"); ForEach(sources, id: \.self) { Text("Android 연결 · " + String($0.suffix(6))).tag($0) } }
            Toggle("걸음·목표를 잠금 화면에 표시", isOn: $liveEnabled).accessibilityIdentifier("steps-live-toggle")
            Text(live.stepsMessage).font(.caption).foregroundStyle(.secondary)
            Text("켜면 걸음 수와 목표가 잠금 화면·다이내믹 아일랜드에 보일 수 있어요. 앱 보관값이며 새로고침은 앱에서 해주세요.").font(.caption).foregroundStyle(.secondary)
            Text("선택한 출처만 표시해요. iPhone·Android 집계를 서로 더하지 않아요.").font(.caption).foregroundStyle(.secondary)
        }.careCard()
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("최근 7일, 나의 걸음").font(.title3.bold())
            Chart(rows) { row in BarMark(x: .value("날짜", row.day), y: .value("걸음", row.count)).foregroundStyle(.orange).cornerRadius(4) }.frame(height: 150).chartYAxis(.hidden)
            let total = rows.reduce(0) { $0 + $1.count }
            Text(rows.isEmpty ? "읽은 기록이 없어요" : "\(rows.count)일 기록 · 평균 \(total / rows.count)걸음 · 현재 목표 이상 \(rows.filter { $0.count >= StepTotals.goal(goal) }.count)일").font(.subheadline)
            ForEach((0..<7).reversed(), id: \.self) { offset in
                let day = dayOffset(-offset); let count = rows.first { $0.day == dateKey(day) }?.count
                HStack { Text(koreanDate(day)); Spacer(); Text(count.map { $0.formatted() + " 걸음" } ?? "데이터 없음").monospacedDigit() }.font(.subheadline)
            }
            Text("없는 날짜는 평균에서 제외해요. 과거 목표 달성 기록이 아니라 현재 목표와 비교한 값이에요.").font(.caption).foregroundStyle(.secondary)
        }.careCard()
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareButton(title: "걸음 읽기 권한 요청", id: "steps-authorize") { Task { await health.refresh(authorize: true) } }.disabled(health.busy)
            CareButton(title: "지금 걸음 새로고침", id: "steps-refresh") { Task { await health.refresh(authorize: false) } }.disabled(health.busy)
            if health.busy { ProgressView("일별 걸음 확인 중") }
            Text(health.status).font(.caption).accessibilityIdentifier("steps-status")
            if let date = health.refreshed { Text("마지막 읽기: " + date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
            Text("Apple 건강 통계 API의 일별 집계예요. 센서 실시간 측정이 아닌 새로고침 시점의 값이며 HealthKit 서명이 필요해요.").font(.caption).foregroundStyle(.secondary)
            Button("이 화면의 Apple 걸음 보관값 지우기", role: .destructive) { deleting = true }.disabled(health.busy)
        }.careCard()
    }
}
