import Foundation
struct SleepAudioCoverage {
    let elapsedSeconds: Double
    let usedMonotonic: Bool
    let recordedSeconds: Double
    var gapSeconds: Double { max(0, elapsedSeconds - recordedSeconds) }
    var fraction: Double { min(1, recordedSeconds / elapsedSeconds) }
    static func analyze(start: Date, end: Date?, seconds: [Double], recovered: Bool, monotonic: Double? = nil) -> SleepAudioCoverage? {
        guard !recovered, let end, start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, start.timeIntervalSince1970 > 0, seconds.count <= 480 else { return nil }
        let elapsed = monotonic ?? end.timeIntervalSince(start)
        guard elapsed.isFinite, elapsed >= 1, elapsed <= 9*3600, seconds.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 65 }) else { return nil }
        let recorded = seconds.reduce(0,+)
        guard recorded <= elapsed + 2 else { return nil }
        return SleepAudioCoverage(elapsedSeconds: elapsed, usedMonotonic: monotonic != nil, recordedSeconds: recorded)
    }
}
extension SleepSoundSession {
    var audioCoverage: SleepAudioCoverage? { .analyze(start: started, end: ended, seconds: bins.map(\.seconds), recovered: reason.contains("복구"), monotonic: elapsedSeconds) }
}
