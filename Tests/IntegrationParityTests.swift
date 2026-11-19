import XCTest
import SwiftUI
@testable import CareSuiteNative
@testable import CryptoResearchKit
final class IntegrationParityTests:XCTestCase {
    @MainActor func testCarriageDensityAndNativeRendering(){
        XCTAssertEqual(TrainInteriorDensity.counts(0)?.0,0);XCTAssertEqual(TrainInteriorDensity.counts(34)?.1,0);XCTAssertEqual(TrainInteriorDensity.counts(100)?.1,17);XCTAssertEqual(TrainInteriorDensity.counts(200)?.1,42);XCTAssertEqual(TrainInteriorDensity.counts(500)?.1,42);XCTAssertNil(TrainInteriorDensity.counts(.nan));XCTAssertNil(TrainInteriorDensity.counts(-1))
        let render=ImageRenderer(content:TrainInteriorView(percent:135).frame(width:720));XCTAssertNotNil(render.uiImage)
        if let image=render.uiImage{let attachment=XCTAttachment(image:image);attachment.name="Native carriage density illustration";attachment.lifetime = .keepAlways;add(attachment)}
    }
    func testPublicLiquidationSemantics()throws{
        let now:Int64=1800000000000
        let sample:[String:Any]=["topic":"allLiquidation.BTCUSDT","data":[["s":"BTCUSDT","S":"Buy","T":now,"p":"90000","v":"1.5"]]]
        let rows=try PublicMarketParsing.events(sample,symbol:"BTCUSDT",now:now)
        XCTAssertEqual(rows.first?.side,"Buy");XCTAssertEqual(rows.first?.price,90000);XCTAssertEqual(rows.first?.size,1.5)
        XCTAssertTrue(try PublicMarketParsing.events(sample,symbol:"ETHUSDT",now:now).isEmpty)
        XCTAssertThrowsError(try PublicMarketParsing.events(sample,symbol:"BTCUSDT",now:now+600000))
    }
    func testLegacyMetadataPreviewDedupAndInvalidFile()throws{
        let data=Data("[{\"dog\":\"우리 강아지\",\"breed\":\"poodle\",\"date\":\"2026-11-18T12:00:00\",\"note\":\"산책\"},{\"dog\":\"우리 강아지\",\"breed\":\"poodle\",\"date\":\"2026-11-18T12:00:00\",\"note\":\"산책\"}]".utf8)
        let rows=try LegacyPetImport.parse(data);XCTAssertEqual(rows.count,1);XCTAssertEqual(rows.first?.breed,"poodle")
        XCTAssertEqual(try LegacyPetImport.merge(rows,rows).count,1)
        XCTAssertThrowsError(try LegacyPetImport.parse(Data("[{\"date\":\"\"}]".utf8)))
        XCTAssertThrowsError(try LegacyPetImport.parse(Data(repeating:65,count:1_048_577)))
    }
    func testPetJournalMergesWindowsAndExportsWithoutAudio()throws{
        let record=NativePetRecord(id:UUID(),date:Date(),name:"테스트",note:"",file:"test.wav",duration:2,windows:[PetSoundWindow(start:0,end:1,bark:0.8,dog:0.8,speech:0),PetSoundWindow(start:0.5,end:1.5,bark:0.8,dog:0.8,speech:0)])
        let days=PetJournalData.days([record]);XCTAssertEqual(days.first?.2,1);XCTAssertEqual(days.first!.3,1.5,accuracy:0.001)
        let exported=try JSONSerialization.jsonObject(with:PetJournalData.report([record])) as! [String:Any];XCTAssertEqual(exported["schema_version"] as? Int,1)
    }
    func testMissingPrivateTransitResourceIsEmpty(){XCTAssertEqual(TransitDefaults.key(bundle:Bundle(for:Self.self)),"")}
}
