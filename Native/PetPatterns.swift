import Foundation

struct PetSoundWindow: Codable, Equatable {
    let start: Double
    let end: Double
    let bark: Double
    let dog: Double
    let speech: Double
}
struct PetPatternSummary: Equatable {
    let eventCount: Int
    let activeSeconds: Double
    let boutCount: Int
    let medianGap: Double?
}
enum PetPatterns {
    // Merge model windows into events first; overlapping windows are not barks.
    static func summarize(_ windows: [PetSoundWindow], duration: Double, threshold: Double = 0.3) -> PetPatternSummary? {
        guard duration.isFinite, duration > 0, threshold.isFinite, (0...1).contains(threshold) else { return nil }
        let valid = windows.filter { $0.start.isFinite && $0.end.isFinite && $0.bark.isFinite && (0...1).contains($0.bark) && $0.start >= 0 && $0.end > $0.start && $0.end <= duration && $0.bark >= threshold }.sorted { $0.start < $1.start }
        var events: [(Double, Double)] = []
        for window in valid {
            if let last = events.last, window.start <= last.1 {
                events[events.count - 1].1 = max(last.1, window.end)
            } else { events.append((window.start, window.end)) }
        }
        var gaps: [Double] = []
        var bouts = events.isEmpty ? 0 : 1
        for i in events.indices.dropFirst() {
            let gap = max(0, events[i].0 - events[i-1].1)
            gaps.append(gap)
            if gap > 1.5 { bouts += 1 }
        }
        gaps.sort()
        let middle = gaps.count / 2
        let median: Double? = gaps.isEmpty ? nil : (gaps.count % 2 == 1 ? gaps[middle] : (gaps[middle-1] + gaps[middle]) / 2)
        return PetPatternSummary(eventCount: events.count, activeSeconds: events.reduce(0) { $0 + $1.1 - $1.0 }, boutCount: bouts, medianGap: median)
    }
}
