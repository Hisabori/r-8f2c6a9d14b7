// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CryptoResearch", platforms: [.iOS(.v16)], products: [.library(name: "CryptoResearchKit", targets: ["CryptoResearchKit"])], targets: [.target(name: "CryptoResearchKit")], swiftLanguageVersions: [.v5])
