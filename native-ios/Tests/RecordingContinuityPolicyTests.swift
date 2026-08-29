import XCTest
@testable import AudioRecorder

final class RecordingContinuityPolicyTests: XCTestCase {
    func testRepeatedSuccessfulRotationsKeepRecordingIntent() {
        var policy = startedPolicy()

        for _ in 0..<5 {
            XCTAssertEqual(policy.handle(.segmentLimitReached), .rotateSegment)
            XCTAssertEqual(policy.phase, .rotating)
            XCTAssertEqual(policy.handle(.nextSegmentStarted), .none)
            XCTAssertEqual(policy.phase, .recording)
            XCTAssertTrue(policy.hasRecordingIntent)
        }
    }

    func testNextSegmentFailureSchedulesRecoveryInsteadOfStopping() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.segmentLimitReached), .rotateSegment)
        XCTAssertEqual(policy.handle(.nextSegmentFailed), .scheduleRecovery)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)

        XCTAssertEqual(policy.handle(.recoverySucceeded), .none)
        XCTAssertEqual(policy.phase, .recording)
    }

    func testInterruptionResumesOnlyWhenSystemRecommendsIt() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: false)), .none)
        XCTAssertEqual(policy.phase, .interrupted)
        XCTAssertTrue(policy.hasRecordingIntent)

        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: false)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
    }

    func testInterruptionWithResumeRecommendationRecoversImmediately() {
        var policy = startedPolicy()
        _ = policy.handle(.interruptionBegan)

        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: true)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
    }

    func testRelevantRouteChangeRecoversButOverrideDoesNot() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.routeChanged(requiresRestart: false)), .none)
        XCTAssertEqual(policy.phase, .recording)
        XCTAssertEqual(policy.handle(.routeChanged(requiresRestart: true)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    func testBackgroundDoesNotClearIntentAndForegroundRepairsInactiveBackend() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.enteredBackground), .none)
        XCTAssertEqual(policy.phase, .recording)
        XCTAssertTrue(policy.hasRecordingIntent)
        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: true)), .none)
        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: false)), .recover)
    }

    func testRequestedStopIsDifferentFromUnexpectedBackendFailure() {
        var unexpected = startedPolicy()
        XCTAssertEqual(unexpected.handle(.backendFailed), .scheduleRecovery)
        XCTAssertTrue(unexpected.hasRecordingIntent)

        var requested = startedPolicy()
        XCTAssertEqual(requested.handle(.stopRequested), .stopAndClearIntent)
        XCTAssertFalse(requested.hasRecordingIntent)
        XCTAssertEqual(requested.phase, .idle)
    }

    func testAudioFailureCanRecover() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.backendFailed), .scheduleRecovery)
        XCTAssertEqual(policy.handle(.recoveryFailed), .scheduleRecovery)
        XCTAssertTrue(policy.hasRecordingIntent)
        XCTAssertEqual(policy.handle(.recoverySucceeded), .none)
        XCTAssertEqual(policy.phase, .recording)
    }

    func testMediaServicesResetRequiresAudioObjectRebuild() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.mediaServicesLost), .pauseAndFinalize)
        XCTAssertEqual(policy.phase, .awaitingMediaServices)
        XCTAssertEqual(policy.handle(.mediaServicesReset), .rebuildAndRecover)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    private func startedPolicy() -> RecordingContinuityPolicy {
        var policy = RecordingContinuityPolicy()
        XCTAssertEqual(policy.handle(.startRequested), .startBackend)
        XCTAssertEqual(policy.handle(.backendStarted), .none)
        XCTAssertEqual(policy.phase, .recording)
        return policy
    }
}
