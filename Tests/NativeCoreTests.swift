import XCTest
import AVFoundation
@testable import CareSuiteNative

final class NativeCoreTests: XCTestCase {
    func testOverlappingModelWindowsFormOneEvent() throws {
        let windows = [PetSoundWindow(start: 0, end: 1, bark: 0.8, dog: 0.9, speech: 0), PetSoundWindow(start: 0.5, end: 1.5, bark: 0.9, dog: 0.9, speech: 0), PetSoundWindow(start: 4, end: 5, bark: 0.8, dog: 0.9, speech: 0)]
        let value = try XCTUnwrap(PetPatterns.summarize(windows, duration: 5))
        XCTAssertEqual(value.eventCount, 2)
        XCTAssertEqual(value.activeSeconds, 2.5, accuracy: 0.0001)
        XCTAssertEqual(value.boutCount, 2)
        XCTAssertEqual(try XCTUnwrap(value.medianGap), 2.5, accuracy: 0.0001)
    }
    func testInvalidAndLowConfidenceWindowsAreOmitted() {
        let windows = [PetSoundWindow(start: -1, end: 1, bark: 0.9, dog: 1, speech: 0), PetSoundWindow(start: 0, end: 1, bark: .nan, dog: 1, speech: 0), PetSoundWindow(start: 0, end: 1, bark: 0.1, dog: 1, speech: 0)]
        XCTAssertEqual(PetPatterns.summarize(windows, duration: 2)?.eventCount, 0)
        XCTAssertNil(PetPatterns.summarize(windows, duration: .nan))
        XCTAssertNil(PetPatterns.summarize(windows, duration: 0))
    }
    func testPreparationAndMarginAreCountedExactlyOnce() throws {
        let arrival = Date(timeIntervalSince1970: 10000)
        let leave = try XCTUnwrap(NativeTravelPlanning.leaveBy(arrival: arrival, travelSeconds: 600, preparationMinutes: 10, marginMinutes: 5))
        XCTAssertEqual(leave.timeIntervalSince1970, 8500)
        XCTAssertNil(NativeTravelPlanning.leaveBy(arrival: arrival, travelSeconds: .infinity, preparationMinutes: 0, marginMinutes: 0))
        XCTAssertNil(NativeTravelPlanning.leaveBy(arrival: arrival, travelSeconds: 60, preparationMinutes: -1, marginMinutes: 0))
    }
    func testBundledYAMNetRunsOnSyntheticSilence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000))
        buffer.frameLength = 16000
        for i in 0..<16000 { buffer.floatChannelData![0][i] = 0 }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        let (duration, windows) = try PetSoundModel.analyze(url)
        XCTAssertEqual(duration, 1, accuracy: 0.01)
        XCTAssertFalse(windows.isEmpty)
        XCTAssertTrue(windows.allSatisfy { $0.bark.isFinite && $0.end <= duration })
    }
}
