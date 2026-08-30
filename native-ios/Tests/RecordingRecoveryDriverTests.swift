import XCTest
@testable import AudioRecorder

final class RecordingRecoveryDriverTests: XCTestCase {
    private enum Failure: Error {
        case setActive
        case inputUnavailable
        case engineStart
    }

    func testConfigurationChangeAcceptsOnlyCurrentEngineGeneration() {
        let retiredEngine = NSObject()
        let currentEngine = NSObject()

        XCTAssertFalse(RecordingEngineGenerationGate.accepts(
            changedEngine: retiredEngine,
            currentEngine: currentEngine
        ))
        XCTAssertTrue(RecordingEngineGenerationGate.accepts(
            changedEngine: currentEngine,
            currentEngine: currentEngine
        ))
        XCTAssertFalse(RecordingEngineGenerationGate.accepts(
            changedEngine: nil,
            currentEngine: currentEngine
        ))
    }

    func testConfigurationChangeDuringRecoveryInvalidatesInFlightSuccess() {
        var gate = RecordingRecoveryInvalidationGate()
        let attemptTicket = gate.ticket()

        gate.invalidate()

        XCTAssertFalse(gate.accepts(ticket: attemptTicket))
        XCTAssertTrue(gate.accepts(ticket: gate.ticket()))
    }

    func testRepeatedRecoverySignalsCompleteEachSegmentOnlyOnce() {
        var gate = RecordingSegmentCompletionGate()
        let interruptedSegment = gate.beginSegment()

        XCTAssertTrue(gate.claimCompletion(for: interruptedSegment))
        XCTAssertFalse(gate.claimCompletion(for: interruptedSegment))

        let recoveredSegment = gate.beginSegment()
        XCTAssertNotEqual(recoveredSegment, interruptedSegment)
        XCTAssertTrue(gate.claimCompletion(for: recoveredSegment))
        XCTAssertFalse(gate.claimCompletion(for: recoveredSegment))
    }

    func testSuccessfulAttemptUsesRequiredHardwareOrder() throws {
        var driver = RecordingRecoveryDriver()
        var events: [String] = []

        let generation = try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: { events.append("activate") },
            rebuildAudioEngine: { events.append("rebuild:\($0)") },
            validateInputAndOpenSegment: { events.append("input-and-file") },
            installTapAndStartEngine: { events.append("tap-and-start") }
        ))

        XCTAssertEqual(generation, 1)
        XCTAssertEqual(events, ["activate", "rebuild:1", "input-and-file", "tap-and-start"])
    }

    func testSetActiveFailureDoesNotTouchEngineAndNextAttemptRebuilds() throws {
        var driver = RecordingRecoveryDriver()
        var shouldFailActivation = true
        var rebuiltGenerations: [Int] = []

        XCTAssertThrowsError(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {
                if shouldFailActivation { throw Failure.setActive }
            },
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {},
            installTapAndStartEngine: {}
        ))) { error in
            XCTAssertEqual((error as? RecordingRecoveryAttemptError)?.stage, .activateSession)
            XCTAssertNil((error as? RecordingRecoveryAttemptError)?.generation)
        }
        XCTAssertTrue(rebuiltGenerations.isEmpty)

        shouldFailActivation = false
        XCTAssertEqual(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {},
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {},
            installTapAndStartEngine: {}
        )), 1)
        XCTAssertEqual(rebuiltGenerations, [1])
    }

    func testZeroInputFormatForcesFreshEngineOnNextAttempt() throws {
        var driver = RecordingRecoveryDriver()
        var shouldFailInput = true
        var rebuiltGenerations: [Int] = []

        XCTAssertThrowsError(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {},
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {
                if shouldFailInput { throw Failure.inputUnavailable }
            },
            installTapAndStartEngine: {}
        ))) { error in
            XCTAssertEqual((error as? RecordingRecoveryAttemptError)?.stage, .validateInputAndOpenSegment)
            XCTAssertEqual((error as? RecordingRecoveryAttemptError)?.generation, 1)
        }

        shouldFailInput = false
        XCTAssertEqual(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {},
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {},
            installTapAndStartEngine: {}
        )), 2)
        XCTAssertEqual(rebuiltGenerations, [1, 2])
    }

    func testEngineStartFailureForcesFreshEngineOnNextAttempt() throws {
        var driver = RecordingRecoveryDriver()
        var shouldFailStart = true
        var rebuiltGenerations: [Int] = []

        XCTAssertThrowsError(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {},
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {},
            installTapAndStartEngine: {
                if shouldFailStart { throw Failure.engineStart }
            }
        ))) { error in
            XCTAssertEqual((error as? RecordingRecoveryAttemptError)?.stage, .installTapAndStartEngine)
            XCTAssertEqual((error as? RecordingRecoveryAttemptError)?.generation, 1)
        }

        shouldFailStart = false
        XCTAssertEqual(try driver.attempt(using: RecordingRecoveryHardwareSteps(
            activateSession: {},
            rebuildAudioEngine: { rebuiltGenerations.append($0) },
            validateInputAndOpenSegment: {},
            installTapAndStartEngine: {}
        )), 2)
        XCTAssertEqual(rebuiltGenerations, [1, 2])
    }
}
