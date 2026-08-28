import XCTest
@testable import AudioRecorder

final class RecordingModeSessionPolicyTests: XCTestCase {
    func testConfiguredModeIsUsedBeforeRecordingStarts() {
        XCTAssertEqual(
            RecordingModeSessionPolicy.modeForNextSegment(
                configuredMode: .soundActivated,
                activeMode: .everything,
                isRecording: false
            ),
            .soundActivated
        )
    }

    func testEverythingModeRemainsLockedDuringRecording() {
        XCTAssertEqual(
            RecordingModeSessionPolicy.modeForNextSegment(
                configuredMode: .soundActivated,
                activeMode: .everything,
                isRecording: true
            ),
            .everything
        )
    }

    func testSoundActivatedModeRemainsLockedDuringRecording() {
        XCTAssertEqual(
            RecordingModeSessionPolicy.modeForNextSegment(
                configuredMode: .everything,
                activeMode: .soundActivated,
                isRecording: true
            ),
            .soundActivated
        )
    }
}
