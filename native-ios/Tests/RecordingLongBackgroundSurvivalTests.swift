import Foundation
import XCTest
@testable import AudioRecorder

final class RecordingLongBackgroundSurvivalTests: XCTestCase {
    func testAudioActivityPolicyUsesRealBufferFreshnessRatherThanEngineFlag() {
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(RecordingAudioActivityPolicy.isFresh(
            lastActivityAt: Date(timeIntervalSince1970: 96),
            now: now,
            timeout: 5
        ))
        XCTAssertFalse(RecordingAudioActivityPolicy.isFresh(
            lastActivityAt: Date(timeIntervalSince1970: 94),
            now: now,
            timeout: 5
        ))
        XCTAssertFalse(RecordingAudioActivityPolicy.isFresh(
            lastActivityAt: nil,
            now: now,
            timeout: 5
        ))
    }

    func testPreviousProcessWithPersistedIntentIsClassifiedWithoutInventingCause() {
        let priorProcess = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let currentProcess = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let snapshot = RecordingExecutionSnapshot(
            processID: priorProcess,
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            startedAt: Date(timeIntervalSince1970: 10),
            lastAudioActivityAt: Date(timeIntervalSince1970: 90),
            lastSegmentCommittedAt: Date(timeIntervalSince1970: 80),
            receivedTerminationNotification: false
        )

        XCTAssertEqual(
            RecordingExecutionAssessmentPolicy.assess(
                snapshot,
                persistedRecordingIntent: true,
                currentProcessID: currentProcess,
                now: Date(timeIntervalSince1970: 100)
            ),
            .endedWithoutStop(secondsSinceLastAudioActivity: 10, receivedTerminationNotification: false)
        )
    }

    func testCleanStopOrSameProcessDoesNotReportAnUnexpectedExit() {
        let process = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let snapshot = RecordingExecutionSnapshot(
            processID: process,
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            startedAt: Date(timeIntervalSince1970: 10),
            lastAudioActivityAt: Date(timeIntervalSince1970: 90),
            lastSegmentCommittedAt: nil,
            receivedTerminationNotification: false
        )

        XCTAssertEqual(
            RecordingExecutionAssessmentPolicy.assess(
                snapshot,
                persistedRecordingIntent: false,
                currentProcessID: UUID(),
                now: Date(timeIntervalSince1970: 100)
            ),
            .none
        )
        XCTAssertEqual(
            RecordingExecutionAssessmentPolicy.assess(
                snapshot,
                persistedRecordingIntent: true,
                currentProcessID: process,
                now: Date(timeIntervalSince1970: 100)
            ),
            .none
        )
    }

    func testExecutionLedgerPersistsHeartbeatAndClearsOnStop() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("execution.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let priorProcess = UUID()
        let session = UUID()
        let ledger = RecordingExecutionLedger(url: url, minimumHeartbeatWriteInterval: 0)
        ledger.begin(processID: priorProcess, sessionID: session, at: Date(timeIntervalSince1970: 10))
        ledger.heartbeat(at: Date(timeIntervalSince1970: 20))

        let reloaded = RecordingExecutionLedger(url: url, minimumHeartbeatWriteInterval: 0)
        XCTAssertEqual(
            reloaded.assessment(
                persistedRecordingIntent: true,
                currentProcessID: UUID(),
                now: Date(timeIntervalSince1970: 25)
            ),
            .endedWithoutStop(secondsSinceLastAudioActivity: 5, receivedTerminationNotification: false)
        )

        reloaded.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRecordingFilesRemainAvailableAfterDeviceLock() {
        XCTAssertEqual(
            RecordingStorage.backgroundRecordingProtection,
            FileProtectionType.completeUntilFirstUserAuthentication
        )
    }

    func testProtectionRequiresTheRecorderToCreateTheDestinationFirst() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("segment.caf")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try RecordingStorage.prepareOpenSegmentForBackgroundRecording(url))
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data()))
        XCTAssertNoThrow(try RecordingStorage.prepareOpenSegmentForBackgroundRecording(url))
    }

    @MainActor
    func testLibraryStartsUnloadedSoRecoveryCanFinishBeforeAutomaticRestart() {
        let library = RecordingLibrary()
        XCTAssertFalse(library.isLoaded)
    }
}
