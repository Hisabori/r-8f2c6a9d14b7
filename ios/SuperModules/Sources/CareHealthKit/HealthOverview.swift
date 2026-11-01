import SwiftUI

struct HealthCheckRow: Identifiable {
    let kind: String
    let value: Double?
    let recordedDays: Int
    var id: String { kind }
}
enum HealthOverviewMetrics {
    static let kinds = ["물", "운동", "수면", "마음"]
    static func focus(_ raw: String) -> String { kinds.contains(raw) ? raw : "물" }
    static func snapshotDate(offset raw: Int, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let offset = min(6, max(0, raw))
        guard offset > 0 else { return now }
        let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
        let end = calendar.date(byAdding: .day, value: 1, to: day)!
        return Date(timeIntervalSinceReferenceDate: end.timeIntervalSinceReferenceDate.nextDown)
    }
    static func rows(_ entries: [Entry], focus raw: String, now: Date = Date(), calendar: Calendar = .current) -> [HealthCheckRow] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let selected = focus(raw)
        let order = [selected] + kinds.filter { $0 != selected }
        return order.map { kind in
            let records = entries.filter { entry in
                guard entry.kind == kind, entry.source == nil || entry.source == "", !entry.id.hasPrefix("hc:"), entry.date >= start, entry.date <= now, entry.date.timeIntervalSince1970 > 0, entry.value.isFinite, entry.value > 0 else { return false }
                let max: Double = kind == "마음" ? 5 : kind == "수면" ? 24 : kind == "운동" ? 1440 : 20000
                return entry.value <= max && (kind != "마음" || entry.value.rounded() == entry.value)
            }
            let current = records.filter { $0.date >= today }
            let value: Double?
            if current.isEmpty { value = nil }
            else if kind == "물" || kind == "운동" { value = current.reduce(0) { $0 + $1.value } }
            else { value = current.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }.first?.value }
            return HealthCheckRow(kind: kind, value: value, recordedDays: Set(records.map { calendar.startOfDay(for: $0.date) }).count)
        }
    }
}
struct HealthOverviewCard: View {
    @EnvironmentObject private var journal: Journal
    @AppStorage("health-overview-focus-v1") private var focus = "물"
    @State private var dayOffset = 0
    private var snapshot: Date { HealthOverviewMetrics.snapshotDate(offset: dayOffset) }
    let open: (String) -> Void
    let openGoals: () -> Void
    private var rows: [HealthCheckRow] { HealthOverviewMetrics.rows(journal.entries, focus: focus, now: snapshot) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(dayOffset == 0 ? "오늘, 나를 챙기는 기록" : "그날의 나를 돌아보기", systemImage: "heart.text.square").font(.title3.bold())
            HStack {
                Button("이전 날") { dayOffset = min(6, dayOffset + 1) }.disabled(dayOffset >= 6).accessibilityIdentifier("health-day-prev")
                Spacer()
                Text(dayOffset == 0 ? "오늘" : koreanDate(snapshot, weekday: true)).font(.subheadline.bold()).accessibilityIdentifier("health-day-label")
                Spacer()
                Button("다음 날") { dayOffset = max(0, dayOffset - 1) }.disabled(dayOffset == 0).accessibilityIdentifier("health-day-next")
            }.frame(minHeight: 44)
            Text("선택일 직접 기록한 항목 \(rows.filter { $0.value != nil }.count) / 4").font(.subheadline).accessibilityIdentifier("health-overview-count")
            Text("건강 점수가 아닌 기록 현황이에요. 비어 있어도 괜찮아요.").font(.caption).foregroundStyle(.secondary)
            Picker("먼저 볼 항목", selection: $focus) { ForEach(HealthOverviewMetrics.kinds, id: \.self) { Text($0 == "물" ? "수분" : $0).tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("health-overview-focus")
            ForEach(rows) { row in
                Button { if dayOffset == 0 { open(row.kind) } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: symbol(row.kind)).foregroundStyle(Palette.color(row.kind)).frame(width: 24)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.kind == "물" ? "수분" : row.kind).font(.headline)
                            Text("선택일 포함 7일 · \(row.recordedDays)일 직접 기록").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 6)
                        Text(value(row)).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8).frame(minHeight: 52)
                }.buttonStyle(.plain).disabled(dayOffset != 0).accessibilityIdentifier("health-overview-" + row.kind)
            }
            let next = rows.first { $0.value == nil }?.kind ?? HealthOverviewMetrics.focus(focus)
            if dayOffset == 0 {
                CareButton(title: "기록 열기 · " + (next == "물" ? "수분" : next), id: "health-overview-next") { open(next) }
            } else {
                Text("지난 날짜는 보기 전용이에요. 새 기록은 오늘로 돌아간 뒤 남겨주세요.").font(.caption).foregroundStyle(.secondary)
                CareButton(title: "오늘로 돌아가기", id: "health-day-today") { dayOffset = 0 }
            }
            Button("내 목표 조정하기", action: openGoals).font(.subheadline).accessibilityIdentifier("health-overview-goals")
            Text("수분·운동은 선택일 합계, 수면·마음은 선택일의 최근 직접 기록이에요. 연동 원본과 만보기는 별도 화면에서 확인해요.").font(.caption).foregroundStyle(.secondary)
        }.careCard()
    }
    private func value(_ row: HealthCheckRow) -> String {
        guard let n = row.value else { return dayOffset == 0 ? "아직 기록 전" : "기록 없음" }
        if row.kind == "마음" { return moodNames[max(0, min(4, Int(n) - 1))] }
        return number(n) + " " + unit(row.kind)
    }
}
