import XCTest
@testable import AudioRecorder

final class RecordingDiagnosticsTests: XCTestCase {
    func testProductionBuildDisablesExportAndPersistentEventTrail() {
        XCTAssertFalse(RecordingDiagnosticPrivacyPolicy.userVisibleExportEnabled)
        XCTAssertFalse(RecordingDiagnosticPrivacyPolicy.persistedEventTrailEnabled)
    }

    func testCallInterruptionCodesContainNoCallMetadata() {
        let forbidden = [
            "phone", "number", "contact", "caller", "callkit"
        ]
        let codes: [RecordingDiagnosticCode] = [
            .enteredInactive,
            .interruptionBegan,
            .interruptionEndedResume,
            .interruptionEndedNoResume
        ]

        for code in codes {
            for term in forbidden {
                XCTAssertFalse(code.rawValue.lowercased().contains(term))
            }
        }
    }

    func testRuntimeStateContainsOnlyTechnicalLivenessValues() {
        let state = RecordingDiagnosticRuntimeState(
            recordingIntent: true,
            engineRunning: false,
            inputSampleRate: 0,
            inputChannelCount: 0,
            interrupted: true,
            recovering: false,
            retryScheduled: true
        )

        XCTAssertTrue(state.recordingIntent)
        XCTAssertTrue(state.interrupted)
        XCTAssertTrue(state.retryScheduled)
        XCTAssertFalse(state.engineRunning)
        XCTAssertFalse(state.recovering)
    }
}
