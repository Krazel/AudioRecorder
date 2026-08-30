import XCTest
@testable import AudioRecorder

final class RecordingDiagnosticsTests: XCTestCase {
    func testInternalExportIsAvailableOnlyForTheOfficialDemoAdBuild() {
        XCTAssertTrue(InternalRecordingDiagnosticsAvailability.isEnabled(
            adMobAppID: "ca-app-pub-3940256099942544~1458002511"
        ))
        XCTAssertFalse(InternalRecordingDiagnosticsAvailability.isEnabled(
            adMobAppID: "ca-app-pub-1111111111111111~2222222222"
        ))
        XCTAssertFalse(InternalRecordingDiagnosticsAvailability.isEnabled(adMobAppID: nil))
    }

    func testDiagnosticBufferKeepsOnlyNewestEntries() {
        let entries = (0..<5).map { entry(detailCode: $0) }
        var buffered: [RecordingDiagnosticEntry] = []

        for entry in entries {
            buffered = RecordingDiagnosticBuffer.appending(entry, to: buffered, limit: 3)
        }

        XCTAssertEqual(buffered.map(\.detailCode), [2, 3, 4])
    }

    func testDiagnosticSchemaContainsNoAudioOrFileContentFields() throws {
        let data = try JSONEncoder().encode(entry(detailCode: 7))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(
            Set(object.keys),
            Set([
                "timestamp",
                "sessionID",
                "code",
                "phase",
                "mode",
                "detailCode",
                "runtime"
            ])
        )
        let runtime = try XCTUnwrap(object["runtime"] as? [String: Any])
        XCTAssertEqual(
            Set(runtime.keys),
            Set([
                "recordingIntent",
                "engineRunning",
                "inputSampleRate",
                "inputChannelCount",
                "interrupted",
                "recovering",
                "retryScheduled"
            ])
        )
        let json = String(decoding: data, as: UTF8.self).lowercased()
        XCTAssertFalse(json.contains("audio"))
        XCTAssertFalse(json.contains("filename"))
        XCTAssertFalse(json.contains("path"))
        XCTAssertFalse(json.contains("transcript"))
    }

    func testExportDocumentContainsOnlyVersionDateAndSanitizedEntries() throws {
        let document = RecordingDiagnosticExportDocument(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 123),
            appVersion: "1.0.6",
            buildNumber: "1",
            operatingSystemVersion: "Version 26.0",
            entries: [entry(detailCode: 3)]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(
            Set(object.keys),
            Set([
                "schemaVersion",
                "generatedAt",
                "appVersion",
                "buildNumber",
                "operatingSystemVersion",
                "entries"
            ])
        )
        XCTAssertEqual((object["entries"] as? [[String: Any]])?.count, 1)

        let json = String(decoding: data, as: UTF8.self).lowercased()
        for forbidden in ["filename", "filepath", "transcript", "hardware", "device", "account", "email"] {
            XCTAssertFalse(json.contains(forbidden), "Unexpected diagnostic field: \(forbidden)")
        }
    }

    func testInterruptionOptionsAndRecoveryStateAreRepresentableWithoutUserContent() throws {
        let state = RecordingDiagnosticRuntimeState(
            recordingIntent: true,
            engineRunning: false,
            inputSampleRate: 0,
            inputChannelCount: 0,
            interrupted: true,
            recovering: false,
            retryScheduled: true
        )
        let entry = RecordingDiagnosticEntry(
            timestamp: Date(timeIntervalSince1970: 1),
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            code: .interruptionEndedNoResume,
            phase: "retryScheduled",
            mode: "everything",
            detailCode: 0,
            interruptionType: 1,
            interruptionOptions: 0,
            interruptionReason: 1,
            interruptionWasSuspended: true,
            recoveryStage: RecordingRecoveryStage.activateSession.rawValue,
            errorDomain: "NSOSStatusErrorDomain",
            errorCode: -50,
            runtime: state
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(RecordingDiagnosticEntry.self, from: data)

        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.detailCode, 0)
        XCTAssertEqual(decoded.interruptionReason, 1)
        XCTAssertEqual(decoded.interruptionWasSuspended, true)
        XCTAssertEqual(decoded.recoveryStage, RecordingRecoveryStage.activateSession.rawValue)
        XCTAssertEqual(decoded.errorDomain, "NSOSStatusErrorDomain")
        XCTAssertEqual(decoded.runtime, state)
    }

    private func entry(detailCode: Int) -> RecordingDiagnosticEntry {
        RecordingDiagnosticEntry(
            timestamp: Date(timeIntervalSince1970: TimeInterval(detailCode)),
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            code: .routeChanged,
            phase: "recording",
            mode: "everything",
            detailCode: detailCode,
            interruptionType: nil,
            interruptionOptions: nil,
            interruptionReason: nil,
            interruptionWasSuspended: nil,
            recoveryStage: nil,
            errorDomain: nil,
            errorCode: nil,
            runtime: RecordingDiagnosticRuntimeState(
                recordingIntent: true,
                engineRunning: false,
                inputSampleRate: 0,
                inputChannelCount: 0,
                interrupted: false,
                recovering: false,
                retryScheduled: false
            )
        )
    }
}
