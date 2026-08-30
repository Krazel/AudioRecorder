import Foundation

enum RecordingRecoveryStage: String, Equatable {
    case activateSession
    case rebuildAudioEngine
    case validateInputAndOpenSegment
    case installTapAndStartEngine
}

struct RecordingRecoveryAttemptError: LocalizedError {
    let generation: Int?
    let stage: RecordingRecoveryStage
    let underlyingError: Error

    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}

/// Injectable, deterministic ordering for one hardware recovery attempt.
/// `RecorderService` supplies the AVFoundation closures; tests supply fakes that
/// fail each hardware boundary without requiring a simulator microphone.
struct RecordingRecoveryHardwareSteps {
    let activateSession: () throws -> Void
    let rebuildAudioEngine: (_ generation: Int) -> Void
    let validateInputAndOpenSegment: () throws -> Void
    let installTapAndStartEngine: () throws -> Void
}

/// Accepts hardware events only from the engine generation currently owned by
/// `RecorderService`. AVFoundation can deliver a queued configuration-change
/// notification after that engine has already been replaced.
enum RecordingEngineGenerationGate {
    static func accepts(changedEngine: AnyObject?, currentEngine: AnyObject) -> Bool {
        changedEngine === currentEngine
    }
}

/// A ticket makes an in-flight recovery fail closed if AVFoundation invalidates
/// the graph before that attempt commits success.
struct RecordingRecoveryInvalidationGate {
    private(set) var revision = 0

    mutating func invalidate() {
        revision &+= 1
    }

    func ticket() -> Int {
        revision
    }

    func accepts(ticket: Int) -> Bool {
        ticket == revision
    }
}

struct RecordingRecoveryInvalidatedError: LocalizedError {
    var errorDescription: String? {
        "The audio engine changed while recovery was in progress."
    }
}

/// Owns exactly one completion claim for the segment currently attached to the
/// capture backend. Repeated interruption/configuration signals can finalize it
/// only once; opening the next file creates a distinct claim.
struct RecordingSegmentCompletionGate {
    private(set) var currentToken: UUID?

    mutating func beginSegment() -> UUID {
        let token = UUID()
        currentToken = token
        return token
    }

    mutating func claimCompletion(for token: UUID) -> Bool {
        guard currentToken == token else { return false }
        currentToken = nil
        return true
    }

    mutating func clear() {
        currentToken = nil
    }
}

struct RecordingRecoveryDriver {
    private(set) var engineGeneration = 0

    mutating func attempt(using steps: RecordingRecoveryHardwareSteps) throws -> Int {
        do {
            try steps.activateSession()
        } catch {
            throw RecordingRecoveryAttemptError(
                generation: nil,
                stage: .activateSession,
                underlyingError: error
            )
        }

        engineGeneration += 1
        let generation = engineGeneration
        steps.rebuildAudioEngine(generation)

        do {
            try steps.validateInputAndOpenSegment()
        } catch {
            throw RecordingRecoveryAttemptError(
                generation: generation,
                stage: .validateInputAndOpenSegment,
                underlyingError: error
            )
        }

        do {
            try steps.installTapAndStartEngine()
        } catch {
            throw RecordingRecoveryAttemptError(
                generation: generation,
                stage: .installTapAndStartEngine,
                underlyingError: error
            )
        }

        return generation
    }
}
