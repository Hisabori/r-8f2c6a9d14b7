import Foundation

enum NativeActivityText {
    static func pet(_ signal: String,stale: Bool) -> String {
        if stale { return "앱에서 상태 확인" }
        switch signal {
        case "recording": return "소리 녹음 중"
        case "processing": return "녹음 파일 분석 중"
        case "done": return "소리 기록 완료"
        case "stopped": return "녹음 종료"
        case "bark": return "짖음 소리 후보"
        case "dog": return "강아지 소리 후보"
        case "speech": return "말소리 반응"
        case "quiet": return "뚜렷한 짖음 반응 없음"
        default: return "소리 상태 확인 중"
        }
    }
    static func compactSteps(_ value: Int) -> String {
        let value = min(1_000_000,max(0,value))
        return value >= 10_000 ? String(format:"%.1f만",Double(value)/10_000):String(value)
    }
    static func fresh(_ updated: Date?,at now: Date,maxAge: TimeInterval = 120) -> Bool {
        guard maxAge.isFinite,maxAge >= 0,let updated else { return false }
        return (-5...maxAge).contains(now.timeIntervalSince(updated))
    }
}
