import ActivityKit
import WidgetKit
import SwiftUI

@main struct DepartureWidgetBundle: WidgetBundle {
    var body: some Widget { DepartureWidget(); BarkAnalysisWidget(); ResearchStatusWidget() }
}
struct DepartureWidget: Widget {
    private func stale(_ c: ActivityViewContext<DepartureAttributes>) -> Bool { c.isStale || !NativeActivityText.fresh(c.state.updatedAt,at:Date()) }
    private func title(_ c: ActivityViewContext<DepartureAttributes>) -> String { c.attributes.kind == "preparation" ? "준비 시작":"출발 마감" }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for:DepartureAttributes.self) { c in
            VStack(alignment:.leading,spacing:10) {
                Label(c.attributes.station+" · "+title(c),systemImage:"location.fill").font(.headline).lineLimit(2)
                if stale(c) { Text("이전 경로 예상 · 앱에서 갱신하세요").foregroundStyle(.orange) }
                else { DepartureCountdown(until:c.state.leaveAt).font(.title.bold().monospacedDigit()) }
                Text(c.attributes.train).font(.subheadline).lineLimit(2)
                Text((c.attributes.kind == "preparation" ? "도착 목표 ":"마지막 조회 예측 ")+c.state.trainAt.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(.secondary)
            }.padding(18).activityBackgroundTint(Color(.secondarySystemGroupedBackground)).widgetURL(URL(string:"caresuite-care://service/travel"))
        } dynamicIsland: { c in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("이동 준비",systemImage:"location.fill").font(.caption).lineLimit(1) }
                DynamicIslandExpandedRegion(.trailing) { Text(c.state.trainAt,style:.time).font(.caption).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { VStack(spacing:6) {
                    Text(stale(c) ? "앱에서 경로 갱신":title(c)).font(.headline)
                    if !stale(c) { DepartureCountdown(until:c.state.leaveAt).font(.title2.bold().monospacedDigit()) }
                    Text(c.attributes.train+" · 마지막 계산 기준").font(.caption).lineLimit(2)
                } }
            } compactLeading: { Image(systemName:"location.fill").foregroundStyle(.blue) }
            compactTrailing: {
                if stale(c) { Image(systemName:"arrow.clockwise").accessibilityLabel("경로 갱신 필요") }
                else { DepartureCountdown(until:c.state.leaveAt).font(.caption2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth:52) }
            } minimal: { Image(systemName:stale(c) ? "arrow.clockwise":"location.fill").foregroundStyle(.blue) }
            .widgetURL(URL(string:"caresuite-care://service/travel")).keylineTint(.blue)
        }
    }
}
struct DepartureCountdown: View {
    let until: Date
    var body: some View { let now = Date(); Text(timerInterval:now...max(now,until),countsDown:true,showsHours:false) }
}
struct BarkAnalysisWidget: Widget {
    private func stale(_ c: ActivityViewContext<BarkAnalysisAttributes>) -> Bool { c.isStale || !NativeActivityText.fresh(c.state.updatedAt,at:Date(),maxAge:c.state.signal == "recording" ? 15:90) }
    @ViewBuilder private func detail(_ c: ActivityViewContext<BarkAnalysisAttributes>) -> some View {
        if stale(c) { Text("갱신이 지연됐어요").font(.caption).foregroundStyle(.secondary) }
        else if c.state.signal == "recording" {
            Text(timerInterval:c.attributes.startedAt...c.attributes.startedAt.addingTimeInterval(60),countsDown:false,showsHours:false).monospacedDigit()
            Text("최대 60초 · 앱이 뒤로 가면 녹음 종료").font(.caption)
        } else if c.state.signal == "processing" { ProgressView("기기에서 파일 분석 중").font(.caption) }
        else if c.state.signal == "done" { Text("후보 구간 \(c.state.positive)개 · 분석 창 \(c.state.processed)개").font(.caption);Text("감정·정확도·진단이 아닙니다").font(.caption2).foregroundStyle(.secondary) }
    }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for:BarkAnalysisAttributes.self) { c in
            VStack(alignment:.leading,spacing:10) {
                Label("온케어 · 반려생활",systemImage:"pawprint.fill").font(.headline)
                Text(NativeActivityText.pet(c.state.signal,stale:stale(c))).font(.title3.bold())
                detail(c)
            }.padding(18).activityBackgroundTint(Color(.secondarySystemGroupedBackground)).widgetURL(URL(string:"caresuite-care://service/pet"))
        } dynamicIsland: { c in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("반려생활",systemImage:"pawprint.fill").font(.caption).foregroundStyle(.mint) }
                DynamicIslandExpandedRegion(.trailing) { Text(c.state.signal == "recording" ? "녹음":c.state.signal == "processing" ? "분석":"상태").font(.caption) }
                DynamicIslandExpandedRegion(.bottom) { VStack(spacing:7) { Text(NativeActivityText.pet(c.state.signal,stale:stale(c))).font(.headline);detail(c) } }
            } compactLeading: { Image(systemName:"pawprint.fill").foregroundStyle(.mint) }
            compactTrailing: {
                if !stale(c),c.state.signal == "recording" { Text(timerInterval:c.attributes.startedAt...c.attributes.startedAt.addingTimeInterval(60),countsDown:false,showsHours:false).font(.caption2).monospacedDigit().frame(maxWidth:42) }
                else { Text(stale(c) ? "확인":c.state.signal == "processing" ? "분석":c.state.signal == "done" ? "완료":"상태").font(.caption2).lineLimit(1) }
            } minimal: { Image(systemName:stale(c) ? "exclamationmark.circle":"pawprint.fill").foregroundStyle(.mint) }
            .widgetURL(URL(string:"caresuite-care://service/pet")).keylineTint(.mint)
        }
    }
}
struct ResearchStatusWidget: Widget {
    private func label(_ c: ActivityViewContext<ResearchStatusAttributes>) -> String { c.isStale ? "앱에서 상태 확인":c.state.phase == "loading" ? "자료 확인 중":"자료 확인 종료" }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for:ResearchStatusAttributes.self) { c in
            VStack(alignment:.leading,spacing:10) {
                Label("온케어 · 투자 리서치",systemImage:"chart.xyaxis.line").font(.headline)
                Text(label(c)).font(.title3.bold())
                Text("눌러서 앱에서 결과를 확인하세요").font(.caption).foregroundStyle(.secondary)
            }.padding(18).activityBackgroundTint(Color(.secondarySystemGroupedBackground)).widgetURL(URL(string:"caresuite-care://service/ticker"))
        } dynamicIsland: { c in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("리서치",systemImage:"chart.xyaxis.line").font(.caption).foregroundStyle(.blue) }
                DynamicIslandExpandedRegion(.trailing) { if c.state.phase == "loading",!c.isStale { ProgressView().controlSize(.small) } }
                DynamicIslandExpandedRegion(.bottom) { VStack(spacing:6) { Text(label(c)).font(.headline);Text("눌러서 앱에서 이어보기").font(.caption) } }
            } compactLeading: { Image(systemName:"chart.xyaxis.line").foregroundStyle(.blue) }
            compactTrailing: { Text(c.isStale ? "확인":c.state.phase == "loading" ? "조회":"종료").font(.caption2).lineLimit(1) }
            minimal: { Image(systemName:c.isStale ? "arrow.clockwise":"chart.xyaxis.line").foregroundStyle(.blue) }
            .widgetURL(URL(string:"caresuite-care://service/ticker")).keylineTint(.blue)
        }
    }
}
