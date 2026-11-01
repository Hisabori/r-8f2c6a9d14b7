import XCTest
@testable import CareSuiteNative
@MainActor final class BluetoothSyncTests: XCTestCase {
    func testFramesRejectGapsChangesAndOversizedPayloads() throws {
        func frame(_ offset: UInt32, _ size: UInt32) -> Data {
            var result = Data()
            for n in [offset, size] { result.append(contentsOf: [UInt8((n >> 24)&255), UInt8((n >> 16)&255), UInt8((n >> 8)&255), UInt8(n&255)]) }
            result.append(contentsOf: [1,2,3]); return result
        }
        let valid = try BluetoothHealthSync.frame(frame(0, 31), expectedOffset: 0, total: nil)
        XCTAssertEqual(valid.total, 31); XCTAssertEqual(valid.chunk.count, 3)
        XCTAssertThrowsError(try BluetoothHealthSync.frame(frame(3,31), expectedOffset: 0, total: nil))
        XCTAssertThrowsError(try BluetoothHealthSync.frame(frame(0,32), expectedOffset: 0, total: 31))
        XCTAssertThrowsError(try BluetoothHealthSync.frame(frame(0,2_000_000), expectedOffset: 0, total: nil))
    }
    func testCellularPairDoesNotRequireInventedLANAddress() throws {
        let pair = SyncPair(version: 2, host: "", port: 8766, peer: UUID().uuidString, token: String(repeating: "a", count: 43), fingerprint: String(repeating: "b", count: 64))
        XCTAssertNoThrow(try pair.validate())
        var old = pair; old.version = 1; XCTAssertThrowsError(try old.validate())
        var invalid = pair; invalid.host = "8.8.8.8"; XCTAssertThrowsError(try invalid.validate())
    }
}
