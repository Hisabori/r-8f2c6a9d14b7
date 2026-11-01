import ActivityKit
import Combine
import UIKit

@MainActor final class ProgressLiveStatus: ObservableObject {
    static let shared = ProgressLiveStatus()
    @Published var stepsMessage = "잠금 화면 표시는 꺼져 있어요."
    @Published var soundMessage = "측정 상태의 잠금 화면 표시는 꺼져 있어요."
    private var pending: Task<Void, Never>?
    @available(iOS 16.2, *)
    static func state(kind: CareProgressAttributes.Kind, value: Int, goal: Int, beganAt: Date, now: Date) -> CareProgressAttributes.ContentState? {
        guard beganAt.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite, beganAt > Date(timeIntervalSince1970: 0), now >= beganAt else { return nil }
        if kind == .steps { guard (0...1_000_000).contains(value), (1_000...30_000).contains(goal) else { return nil } }
        else { guard (0...520).contains(value), now.timeIntervalSince(beganAt) <= 8*3600 else { return nil } }
        return .init(value: value, goal: kind == .steps ? goal : 0, beganAt: beganAt, updatedAt: now)
    }
    @available(iOS 16.2, *)
    private func message(_ text: String, kind: CareProgressAttributes.Kind) { if kind == .steps { stepsMessage = text } else { soundMessage = text } }
    @available(iOS 16.2, *)
    func sync(kind: CareProgressAttributes.Kind, sessionID: String, value: Int?, goal: Int = 0, beganAt: Date, enabled: Bool) {
        let previous = pending
        pending = Task {
            await previous?.value
            let existing = Activity<CareProgressAttributes>.activities.filter { $0.attributes.kind == kind }
            guard enabled, let value, let state = Self.state(kind: kind, value: value, goal: goal, beganAt: beganAt, now: Date()) else {
                for activity in existing { await activity.end(nil, dismissalPolicy: .immediate) }
                message(enabled ? "표시할 측정·걸음 기록을 확인해주세요." : "잠금 화면 표시를 종료했어요.", kind: kind); return
            }
            var match: Activity<CareProgressAttributes>?
            for activity in existing {
                if activity.attributes.sessionID == sessionID, match == nil { match = activity }
                else { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(kind == .steps ? 900 : 90))
            if let match { await match.update(content); message("잠금 화면 표시를 갱신했어요.", kind: kind) }
            else if ActivityAuthorizationInfo().areActivitiesEnabled && UIApplication.shared.applicationState == .active {
                do { _ = try Activity.request(attributes: CareProgressAttributes(kind: kind, sessionID: sessionID), content: content, pushType: nil); message("잠금 화면 표시 중 · 실제 배치는 iOS가 결정해요.", kind: kind) }
                catch { message("실시간 현황을 시작하지 못했어요. 기기 설정과 앱 서명을 확인해주세요.", kind: kind) }
            } else { message("앱을 연 상태에서 실시간 현황 허용 설정을 확인해주세요.", kind: kind) }
        }
    }
    func recover(soundRunning: Bool) {
        let previous = pending
        pending = Task {
            await previous?.value
            guard #available(iOS 16.2, *) else { return }
            for activity in Activity<CareProgressAttributes>.activities {
                if (activity.attributes.kind == .sleepSound && (!soundRunning || !UserDefaults.standard.bool(forKey: "sound-live-v1"))) || (activity.attributes.kind == .steps && (!UserDefaults.standard.bool(forKey: "steps-live-v1") || activity.attributes.sessionID != dateKey(Date()))) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
