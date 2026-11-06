import ActivityKit
import SwiftUI
import UIKit

@MainActor final class NativeLiveStatus: ObservableObject {
    static let shared = NativeLiveStatus()
    @Published private(set) var petMessage = "선택하면 녹음·분석 진행 상태를 잠금 화면에 표시해요."
    @Published private(set) var travelMessage = "선택한 준비 시각을 잠금 화면에서 볼 수 있어요."
    private var petTask: Task<Void,Never>?
    private var travelTask: Task<Void,Never>?
    private var researchTask: Task<Void,Never>?
    func petRecording(start: Date,elapsed: Int) { pet(phase:"recording",start:start,elapsed:elapsed) }
    func petProcessing() { pet(phase:"processing",start:Date(),elapsed:0) }
    func petProgress(processed: Int,total: Int) {
        pet(phase:"processing",start:Date(),elapsed:0,processed:processed,total:total)
    }
    private func pet(phase: String,start: Date,elapsed: Int,processed: Int = 0,total: Int? = nil) {
        let prior = petTask
        petTask = Task {
            await prior?.value
            guard #available(iOS 16.2, *) else { petMessage = "실시간 현황은 iOS 16.2 이상에서 사용할 수 있어요.";return }
            guard UserDefaults.standard.bool(forKey:"native-pet-live") else { return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { petMessage = "기기의 실시간 현황 허용 설정을 확인하세요.";return }
            guard UIApplication.shared.applicationState == .active else { return }
            let pool = Activity<BarkAnalysisAttributes>.activities
            for old in pool where old.activityState == .ended || old.activityState == .dismissed { await old.end(nil,dismissalPolicy:.immediate) }
            let all = pool.filter { $0.activityState == .active || $0.activityState == .stale }
            let existing = all.first
            for duplicate in all.dropFirst() { await duplicate.end(nil,dismissalPolicy:.immediate) }
            let state = BarkAnalysisAttributes.ContentState(signal:phase,barkPercent:0,elapsed:min(120,max(0,elapsed)),processed:max(0,processed),positive:0,updatedAt:Date(),total:total)
            let content = ActivityContent(state:state,staleDate:Date().addingTimeInterval(phase == "recording" ? 15:90))
            if let existing { await existing.update(content) }
            else { do { _ = try Activity.request(attributes:BarkAnalysisAttributes(startedAt:start),content:content,pushType:nil) } catch { petMessage = "표시를 시작하지 못했습니다. 기기 설정과 앱 서명을 확인하세요.";return } }
            petMessage = "표시 중 · 실제 아일랜드 배치는 iOS가 결정해요."
        }
    }
    func endPet(events: Int? = nil,windows: Int = 0) {
        let prior = petTask
        petTask = Task {
            await prior?.value
            guard #available(iOS 16.2, *) else { return }
            let activities = Activity<BarkAnalysisAttributes>.activities
            for activity in activities {
                if let events {
                    var state = activity.content.state;state.signal = "done";state.positive = max(0,events);state.processed = max(0,windows);state.updatedAt = Date()
                    await activity.end(ActivityContent(state:state,staleDate:Date().addingTimeInterval(8)),dismissalPolicy:.after(Date().addingTimeInterval(8)))
                } else { await activity.end(nil,dismissalPolicy:.immediate) }
            }
            if !activities.isEmpty { petMessage = events != nil ? "완료 상태를 잠시 표시하고 종료해요.":"진행 표시를 종료했어요." }
        }
    }
    func showTravel(prepareAt: Date,arrival: Date,walkingSeconds: Double,departureAt: Date? = nil) {
        let prior = travelTask
        travelTask = Task {
            await prior?.value
            guard #available(iOS 16.2, *),prepareAt > Date(),arrival > prepareAt,walkingSeconds.isFinite,walkingSeconds >= 0,walkingSeconds <= 86400 else { travelMessage = "앞으로 남은 준비 시각을 먼저 계산하세요.";return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled,UIApplication.shared.applicationState == .active else { travelMessage = "기기의 실시간 현황 허용 설정을 확인하세요.";return }
            for activity in Activity<DepartureAttributes>.activities { await activity.end(nil,dismissalPolicy:.immediate) }
            let now = Date()
            let validDeparture = departureAt.flatMap { $0 >= prepareAt && $0 <= arrival ? $0 : nil }
            let state = DepartureAttributes.ContentState(leaveAt:prepareAt,trainAt:arrival,plannedAt:now,departureAt:validDeparture,updatedAt:now)
            do { _ = try Activity.request(attributes:DepartureAttributes(station:"이동 준비",train:"도보 약 \(Int(ceil(walkingSeconds/60)))분",kind:"preparation"),content:ActivityContent(state:state,staleDate:min(prepareAt,now.addingTimeInterval(120))),pushType:nil);travelMessage = "표시 중 · 경로 예상은 2분 뒤 갱신이 필요해요." }
            catch { travelMessage = "표시를 시작하지 못했습니다. 기기 설정과 앱 서명을 확인하세요." }
        }
    }
    func endTravel() {
        let prior = travelTask
        travelTask = Task { await prior?.value;guard #available(iOS 16.2, *) else { return };for activity in Activity<DepartureAttributes>.activities { await activity.end(nil,dismissalPolicy:.immediate) };travelMessage = "잠금 화면 표시를 종료했어요." }
    }
    func research(active: Bool,enabled: Bool) {
        let prior = researchTask
        researchTask = Task {
            await prior?.value
            guard #available(iOS 16.2, *) else { return }
            let all = Activity<ResearchStatusAttributes>.activities
            if !enabled { for activity in all { await activity.end(nil,dismissalPolicy:.immediate) };return }
            if !active {
                for activity in all { await activity.end(ActivityContent(state:.init(phase:"finished",updatedAt:Date()),staleDate:Date().addingTimeInterval(5)),dismissalPolicy:.after(Date().addingTimeInterval(5))) };return
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled,UIApplication.shared.applicationState == .active else { return }
            let content = ActivityContent(state:ResearchStatusAttributes.ContentState(phase:"loading",updatedAt:Date()),staleDate:Date().addingTimeInterval(90))
            if let first = all.first { await first.update(content);for duplicate in all.dropFirst() { await duplicate.end(nil,dismissalPolicy:.immediate) } }
            else { _ = try? Activity.request(attributes:ResearchStatusAttributes(startedAt:Date()),content:content,pushType:nil) }
        }
    }
    func recover(petRunning: Bool,researchRunning: Bool,researchEnabled: Bool) {
        if !petRunning { endPet() }
        let prior = travelTask
        travelTask = Task {
            await prior?.value
            guard #available(iOS 16.2, *) else { return }
            for activity in Activity<DepartureAttributes>.activities where activity.content.state.trainAt <= Date() {
                await activity.end(nil,dismissalPolicy:.immediate)
            }
        }
        research(active:researchRunning,enabled:researchEnabled)
    }
}
