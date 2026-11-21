import XCTest
import SwiftUI
import CryptoKit
@testable import CareSuiteNative
final class PreviewArtworkTests:XCTestCase {
    @MainActor func testSharedArtworkAndCabinRendering()throws {
        let url=try XCTUnwrap(Bundle.main.url(forResource:"train-cabin-warm-v1",withExtension:"png"))
        XCTAssertEqual(SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined(),"6149e91d7f63d9fbb66889d96e101757a567f96e2c403f425d186556764213f0")
        let renderer=ImageRenderer(content:TrainInteriorView(percent:0,illustrative:true).frame(width:720))
        let image=try XCTUnwrap(renderer.uiImage);let attachment=XCTAttachment(image:image);attachment.name="Warm cabin illustration";attachment.lifetime = .keepAlways;add(attachment)
    }
}
