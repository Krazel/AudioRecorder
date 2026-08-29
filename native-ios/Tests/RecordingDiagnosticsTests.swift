import XCTest
@testable import AudioRecorder

final class RecordingDiagnosticsTests: XCTestCase {
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
                "detailCode"
            ])
        )
        let json = String(decoding: data, as: UTF8.self).lowercased()
        XCTAssertFalse(json.contains("audio"))
        XCTAssertFalse(json.contains("filename"))
        XCTAssertFalse(json.contains("path"))
        XCTAssertFalse(json.contains("transcript"))
    }

    private func entry(detailCode: Int) -> RecordingDiagnosticEntry {
        RecordingDiagnosticEntry(
            timestamp: Date(timeIntervalSince1970: TimeInterval(detailCode)),
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            code: .routeChanged,
            phase: "recording",
            mode: "everything",
            detailCode: detailCode,
            errorDomain: nil,
            errorCode: nil
        )
    }
}
