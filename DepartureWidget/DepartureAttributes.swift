import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct DepartureAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var leaveAt: Date
        var trainAt: Date
        var plannedAt: Date? = nil
        var departureAt: Date? = nil
        var updatedAt: Date?
    }
    var station: String
    var train: String
    var kind: String?
}

@available(iOS 16.2, *)
struct BarkAnalysisAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var signal: String
        var barkPercent: Int
        var elapsed: Int
        var processed: Int
        var positive: Int
        var updatedAt: Date
        var total: Int? = nil
    }
    var startedAt: Date
}

@available(iOS 16.2, *)
struct ResearchStatusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var phase: String;var updatedAt: Date }
    var startedAt: Date
}
