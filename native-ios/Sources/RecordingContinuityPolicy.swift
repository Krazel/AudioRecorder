import Foundation

enum RecordingContinuityPhase: Equatable {
    case idle
    case starting
    case recording
    case rotating
    case interrupted
    case awaitingMediaServices
    case recovering
    case retryScheduled
}

enum RecordingContinuityEvent: Equatable {
    case startRequested
    case startFailed
    case backendStarted
    case segmentLimitReached
    case nextSegmentStarted
    case nextSegmentFailed
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case recoveryOpportunity(backendActive: Bool)
    case routeChanged(requiresRestart: Bool)
    case enteredBackground
    case enteredForeground(backendActive: Bool)
    case backendFailed
    case mediaServicesLost
    case mediaServicesReset
    case recoverySucceeded
    case recoveryFailed
    case stopRequested
}

enum RecordingContinuityAction: Equatable {
    case none
    case startBackend
    case rotateSegment
    case pauseAndFinalize
    case recover
    case rebuildAndRecover
    case scheduleRecovery
    case stopAndClearIntent
}

/// A deterministic model of recording intent. Hardware work stays in
/// `RecorderService`; this policy prevents transient backend failures from being
/// mistaken for a user-requested stop.
struct RecordingContinuityPolicy {
    private(set) var phase: RecordingContinuityPhase = .idle
    private(set) var hasRecordingIntent = false

    mutating func handle(_ event: RecordingContinuityEvent) -> RecordingContinuityAction {
        switch event {
        case .startRequested:
            guard !hasRecordingIntent else { return .none }
            hasRecordingIntent = true
            phase = .starting
            return .startBackend

        case .startFailed:
            hasRecordingIntent = false
            phase = .idle
            return .stopAndClearIntent

        case .backendStarted, .nextSegmentStarted, .recoverySucceeded:
            guard hasRecordingIntent else { return .none }
            phase = .recording
            return .none

        case .segmentLimitReached:
            guard hasRecordingIntent, phase == .recording else { return .none }
            phase = .rotating
            return .rotateSegment

        case .nextSegmentFailed, .backendFailed, .recoveryFailed:
            guard hasRecordingIntent else { return .none }
            phase = .retryScheduled
            return .scheduleRecovery

        case .interruptionBegan:
            guard hasRecordingIntent else { return .none }
            guard phase != .interrupted else { return .none }
            phase = .interrupted
            return .pauseAndFinalize

        case .interruptionEnded:
            guard hasRecordingIntent,
                  phase == .interrupted || phase == .retryScheduled else {
                return .none
            }
            phase = .recovering
            return .recover

        case let .recoveryOpportunity(backendActive):
            guard hasRecordingIntent,
                  phase != .awaitingMediaServices,
                  !backendActive else {
                return .none
            }
            phase = .recovering
            return .recover

        case let .routeChanged(requiresRestart):
            guard hasRecordingIntent,
                  phase != .awaitingMediaServices,
                  requiresRestart else {
                return .none
            }
            phase = .recovering
            return .recover

        case .enteredBackground:
            return .none

        case let .enteredForeground(backendActive):
            guard hasRecordingIntent,
                  phase != .awaitingMediaServices,
                  !backendActive else {
                return .none
            }
            phase = .recovering
            return .recover

        case .mediaServicesLost:
            guard hasRecordingIntent else { return .none }
            phase = .awaitingMediaServices
            return .pauseAndFinalize

        case .mediaServicesReset:
            guard hasRecordingIntent else { return .none }
            phase = .recovering
            return .rebuildAndRecover

        case .stopRequested:
            hasRecordingIntent = false
            phase = .idle
            return .stopAndClearIntent
        }
    }
}
