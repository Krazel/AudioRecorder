import AVFoundation
import XCTest
@testable import AudioRecorder

final class RecordingAudioSessionPolicyTests: XCTestCase {
    func testRecorderUsesBackgroundCompatibleMixablePlayAndRecordSession() {
        XCTAssertEqual(RecordingAudioSessionPolicy.category, .playAndRecord)
        XCTAssertEqual(RecordingAudioSessionPolicy.mode, .default)
        XCTAssertTrue(RecordingAudioSessionPolicy.options.contains(.mixWithOthers))
    }

    func testRecorderPreservesBluetoothInputAndSpeakerRouting() {
        XCTAssertTrue(RecordingAudioSessionPolicy.options.contains(.allowBluetoothHFP))
        XCTAssertTrue(RecordingAudioSessionPolicy.options.contains(.defaultToSpeaker))
        XCTAssertFalse(RecordingAudioSessionPolicy.options.contains(.duckOthers))
        XCTAssertFalse(RecordingAudioSessionPolicy.options.contains(.interruptSpokenAudioAndMixWithOthers))
    }
}
