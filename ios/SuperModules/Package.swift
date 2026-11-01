// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"CareSuperModules",platforms:[.iOS(.v16)],products:[.library(name:"CareHealthKit",targets:["CareHealthKit"]),.library(name:"CryptoResearchKit",targets:["CryptoResearchKit"])],dependencies:[.package(url:"https://github.com/microsoft/onnxruntime-swift-package-manager",exact:"1.20.0")],targets:[.target(name:"CareHealthKit",dependencies:[.product(name:"onnxruntime",package:"onnxruntime-swift-package-manager")]),.target(name:"CryptoResearchKit")],swiftLanguageVersions:[.v5])
