import Foundation
import OSLog

enum RecordingDiagnosticPrivacyPolicy {
    static let userVisibleExportEnabled = false
    static let persistedEventTrailEnabled = false
}

enum RecordingDiagnosticCode: String {
    case startRequested
    case started
    case startFailed
    case stopRequested
    case segmentCompleted
    case rotationRequested
    case rotationSucceeded
    case rotationDeferred
    case backendStoppedUnexpectedly
    case audioInputStalled
    case audioWriteFailed
    case memoryWarningReceived
    case previousExecutionEndedWithoutStop
    case previousExecutionTerminationNotified
    case interruptionBegan
    case interruptionEndedResume
    case interruptionEndedNoResume
    case systemAlertInterruptionPreferenceUnavailable
    case audioEngineConfigurationChanged
    case audioEngineRebuilt
    case routeChanged
    case routeRecoveryStarted
    case enteredInactive
    case enteredBackground
    case enteredForeground
    case mediaServicesLost
    case mediaServicesReset
    case recoveryAttemptStarted
    case audioSessionActivationAttempted
    case audioSessionActivationSucceeded
    case audioSessionActivationFailed
    case recoverySegmentOpened
    case recoveryEngineStartAttempted
    case recoveryEngineStarted
    case recoveryFirstBufferObserved
    case recoveryScheduled
    case recoveryRetryDeduplicated
    case recoveryRetryFired
    case recoveryRetryCancelled
    case recoverySucceeded
    case recoveryFailed
    case inputUnavailable
}

struct RecordingDiagnosticRuntimeState: Equatable {
    let recordingIntent: Bool
    let engineRunning: Bool
    let inputSampleRate: Double
    let inputChannelCount: Int
    let interrupted: Bool
    let recovering: Bool
    let retryScheduled: Bool
}

/// Production-safe observability. Events stay in Apple's unified log and contain
/// only fixed lifecycle codes plus numeric state; nothing is written to an app
/// file and there is no user-visible export path.
@MainActor
final class RecordingDiagnostics {
    private let logger = Logger(subsystem: "com.dmkr.audio.B2X6D3A9J9", category: "recording")

    func record(
        _ code: RecordingDiagnosticCode,
        sessionID: UUID,
        phase: RecordingContinuityPhase,
        mode: RecordingMode?,
        detailCode: Int? = nil,
        interruptionType: Int? = nil,
        interruptionOptions: Int? = nil,
        interruptionReason: Int? = nil,
        interruptionWasSuspended: Bool? = nil,
        recoveryStage: RecordingRecoveryStage? = nil,
        error: Error? = nil,
        runtime: RecordingDiagnosticRuntimeState
    ) {
        let errorCode = error.map { ($0 as NSError).code } ?? 0
        logger.info(
            "event=\(code.rawValue, privacy: .public) phase=\(String(describing: phase), privacy: .public) mode=\(mode?.rawValue ?? "none", privacy: .public) detail=\(detailCode ?? -1, privacy: .public) interruptionType=\(interruptionType ?? -1, privacy: .public) interruptionOptions=\(interruptionOptions ?? -1, privacy: .public) interruptionReason=\(interruptionReason ?? -1, privacy: .public) suspended=\(interruptionWasSuspended ?? false, privacy: .public) recovery=\(recoveryStage?.rawValue ?? "none", privacy: .public) error=\(errorCode, privacy: .public) intent=\(runtime.recordingIntent, privacy: .public) engine=\(runtime.engineRunning, privacy: .public) interrupted=\(runtime.interrupted, privacy: .public) recovering=\(runtime.recovering, privacy: .public) retry=\(runtime.retryScheduled, privacy: .public)"
        )

        // Accepted to keep call sites explicit, but never logged because they
        // can fingerprint a session or hardware characteristics.
        _ = sessionID
        _ = runtime.inputSampleRate
        _ = runtime.inputChannelCount
    }
}
