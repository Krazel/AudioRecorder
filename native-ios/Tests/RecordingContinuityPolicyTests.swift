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

    func testExplicitRecordingIntentRecoversWhenInterruptionEndsWithoutRecommendation() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: false)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    func testInterruptionWithResumeRecommendationRecoversImmediately() {
        var policy = startedPolicy()
        _ = policy.handle(.interruptionBegan)

        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: true)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
    }

    func testMissingInterruptionEndRecoversAtNextRetryOpportunity() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
        XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: false)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    func testActivationAndEngineFailuresRetryUntilRecoverySucceeds() {
        var policy = startedPolicy()
        _ = policy.handle(.interruptionBegan)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: false)), .recover)

        for _ in 0..<3 {
            XCTAssertEqual(policy.handle(.recoveryFailed), .scheduleRecovery)
            XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: false)), .recover)
        }

        XCTAssertEqual(policy.handle(.recoverySucceeded), .none)
        XCTAssertEqual(policy.phase, .recording)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    func testInterruptionEndRetriesImmediatelyAfterAnEarlierRecoveryFailure() {
        var policy = startedPolicy()

        _ = policy.handle(.interruptionBegan)
        XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: false)), .recover)
        XCTAssertEqual(policy.handle(.recoveryFailed), .scheduleRecovery)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: false)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
    }

    func testNoResumeRecommendationCanRecoverOnForegroundAfterActivationFailure() {
        var policy = startedPolicy()

        _ = policy.handle(.interruptionBegan)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: false)), .recover)
        XCTAssertEqual(policy.handle(.recoveryFailed), .scheduleRecovery)
        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: false)), .recover)
        XCTAssertEqual(policy.phase, .recovering)
        XCTAssertTrue(policy.hasRecordingIntent)
    }

    func testStopDuringInterruptionCancelsEveryLaterRecoverySignal() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
        XCTAssertEqual(policy.handle(.stopRequested), .stopAndClearIntent)
        XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: true)), .none)
        XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: false)), .none)
        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: false)), .none)
        XCTAssertFalse(policy.hasRecordingIntent)
        XCTAssertEqual(policy.phase, .idle)
    }

    func testMultipleInterruptionsResumeWithoutDuplicatingTheBackend() {
        var policy = startedPolicy()

        for shouldResume in [true, false, true] {
            XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
            XCTAssertEqual(policy.handle(.interruptionBegan), .none)
            XCTAssertEqual(
                policy.handle(.interruptionEnded(shouldResume: shouldResume)),
                .recover
            )
            XCTAssertEqual(policy.handle(.interruptionEnded(shouldResume: shouldResume)), .none)
            XCTAssertEqual(policy.handle(.recoverySucceeded), .none)
            XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: true)), .none)
            XCTAssertEqual(policy.phase, .recording)
        }
    }

    func testInterruptionFinalizesOneValidSegmentWithoutClearingIntent() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.interruptionBegan), .pauseAndFinalize)
        XCTAssertEqual(policy.handle(.interruptionBegan), .none)
        XCTAssertTrue(policy.hasRecordingIntent)
        XCTAssertEqual(policy.phase, .interrupted)
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

    func testRetryOpportunityNeverStartsASecondActiveBackend() {
        var policy = startedPolicy()

        XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: true)), .none)
        XCTAssertEqual(policy.phase, .recording)
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
        XCTAssertEqual(policy.handle(.enteredForeground(backendActive: false)), .none)
        XCTAssertEqual(policy.handle(.recoveryOpportunity(backendActive: false)), .none)
        XCTAssertEqual(policy.handle(.routeChanged(requiresRestart: true)), .none)
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
