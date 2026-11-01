import SwiftUI
import WidgetKit
import ActivityKit

struct CareProgressLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CareProgressAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(title(context), systemImage: icon(context)).font(.headline)
                value(context).font(.title2.bold()).monospacedDigit()
                if context.attributes.kind == .steps {
                    ProgressView(value: min(1, Double(context.state.value)/Double(max(1,context.state.goal)))).tint(.orange)
                    Text("목표 \(context.state.goal)걸음 · 앱 보관값, 새로고침은 앱에서").font(.caption)
                } else { Text("분 단위 소리 요약 · 실제 수면 시간이 아니에요").font(.caption) }
                Text(context.isStale ? "갱신 지연 · 앱에서 상태를 확인해주세요" : "표시 갱신 " + context.state.updatedAt.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            }.padding(18).widgetURL(destination(context)).activityBackgroundTint(Color(.secondarySystemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: icon(context)).foregroundStyle(tint(context)) }
                DynamicIslandExpandedRegion(.trailing) { Text(title(context)).font(.caption) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        value(context).font(.title2.bold()).monospacedDigit()
                        Text(context.isStale ? "갱신 지연 · 앱에서 확인" : context.attributes.kind == .steps ? "앱 보관값 · 목표 \(context.state.goal)걸음" : "측정 경과 · 소리 요약 \(context.state.value)분").font(.caption)
                    }
                }
            } compactLeading: { Image(systemName: icon(context)).foregroundStyle(tint(context)) }
            compactTrailing: { if context.isStale { Text("확인").font(.caption) } else if context.attributes.kind == .steps { Text("\(context.state.value)").monospacedDigit() } else { value(context).monospacedDigit().frame(maxWidth: 58) } }
            minimal: { Image(systemName: icon(context)).foregroundStyle(tint(context)) }
            .widgetURL(destination(context)).keylineTint(tint(context))
        }
    }
    private func title(_ c: ActivityViewContext<CareProgressAttributes>) -> String { c.attributes.kind == .steps ? "온케어 · 걸음 목표" : "온케어 · 수면 소리" }
    private func icon(_ c: ActivityViewContext<CareProgressAttributes>) -> String { c.attributes.kind == .steps ? "figure.walk" : "waveform" }
    private func tint(_ c: ActivityViewContext<CareProgressAttributes>) -> Color { c.attributes.kind == .steps ? .orange : .purple }
    private func destination(_ c: ActivityViewContext<CareProgressAttributes>) -> URL { c.attributes.kind == .steps ? CareDestination.steps.url : CareDestination.sleepSound.url }
    @ViewBuilder private func value(_ c: ActivityViewContext<CareProgressAttributes>) -> some View {
        if c.isStale { Text("앱에서 상태 확인") }
        else if c.attributes.kind == .steps { Text("\(c.state.value) 걸음") }
        else { Text(timerInterval: c.state.beganAt...c.state.beganAt.addingTimeInterval(8*3600), countsDown: false) }
    }
}
