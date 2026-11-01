import ActivityKit
import Foundation
@available(iOS 16.2, *)
struct CareProgressAttributes: ActivityAttributes {
    enum Kind: String, Codable { case steps, sleepSound }
    struct ContentState: Codable, Hashable {
        var value: Int
        var goal: Int
        var beganAt: Date
        var updatedAt: Date
    }
    var kind: Kind
    var sessionID: String
}
