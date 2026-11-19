import Foundation
enum TransitDefaults {
    static func key(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "transit-default", withExtension: "json"),
              let data = try? Data(contentsOf: url), data.count <= 2048,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let value = object["seoul_subway_key"], (1...128).contains(value.utf8.count),
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else { return "" }
        return value
    }
}
