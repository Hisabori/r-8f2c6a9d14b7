import XCTest
@testable import CryptoResearch
final class ServerConnectionTests:XCTestCase {
 func testHTTPSAddressPolicy()throws{XCTAssertEqual(try PaperServerAPI.canonical("https://gram.example.com/").host,"gram.example.com");for raw in ["http://gram.example.com","https://u:p@gram.example.com","https://gram.example.com/path","https://gram.example.com?token=x","https://gram.example.com#x"]{XCTAssertThrowsError(try PaperServerAPI.canonical(raw))}}
}
