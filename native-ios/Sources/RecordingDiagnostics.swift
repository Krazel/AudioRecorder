import Foundation
import OSLog

enum RecordingDiagnosticCode: String, Codable {
    case startRequested
    case started
    case startFailed
    case stopRequested
    case segmentCompleted
    case rotationRequested
    case rotationSucceeded
    case rotationDeferred
    case backendStoppedUnexpectedly
    case audioWriteFailed
    case interruptionBegan
    case interruptionEndedResume
    case interruptionEndedNoResume
    case routeChanged
    case routeRecoveryStarted
    case enteredBackground
    case enteredForeground
    case mediaServicesLost
    case mediaServicesReset
    case recoveryScheduled
    case recoverySucceeded
    case recoveryFailed
    case inputUnavailable
}

struct RecordingDiagnosticEntry: Codable, Equatable {
    let timestamp: Date
    let sessionID: UUID
    let code: RecordingDiagnosticCode
    let phase: String
    let mode: String?
    let detailCode: Int?
    let errorDomain: String?
    let errorCode: Int?
}

enum RecordingDiagnosticBuffer {
    static func appending(
        _ entry: RecordingDiagnosticEntry,
        to entries: [RecordingDiagnosticEntry],
        limit: Int
    ) -> [RecordingDiagnosticEntry] {
        guard limit > 0 else { return [] }
        return Array((entries + [entry]).suffix(limit))
    }
}

/// A small, bounded, device-local diagnostic trail. It records only lifecycle
/// codes and numeric error metadata: never audio, filenames, routes, labels,
/// account identifiers, or user-entered content.
@MainActor
final class RecordingDiagnostics {
    private let logger = Logger(subsystem: "com.dmkr.audio.B2X6D3A9J9", category: "recording")
    private let maximumEntries = 200
    private var cachedEntries: [RecordingDiagnosticEntry]?

    private var logURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches
            .appendingPathComponent("RecordingDiagnostics", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    func record(
        _ code: RecordingDiagnosticCode,
        sessionID: UUID,
        phase: RecordingContinuityPhase,
        mode: RecordingMode?,
        detailCode: Int? = nil,
        error: Error? = nil
    ) {
        let nsError = error.map { $0 as NSError }
        let entry = RecordingDiagnosticEntry(
            timestamp: Date(),
            sessionID: sessionID,
            code: code,
            phase: String(describing: phase),
            mode: mode?.rawValue,
            detailCode: detailCode,
            errorDomain: nsError?.domain,
            errorCode: nsError?.code
        )

        logger.info("event=\(code.rawValue, privacy: .public) phase=\(entry.phase, privacy: .public) detail=\(detailCode ?? -1, privacy: .public) error=\(nsError?.code ?? 0, privacy: .public)")

        guard let logURL else { return }
        let entries = RecordingDiagnosticBuffer.appending(
            entry,
            to: cachedEntries ?? loadEntries(from: logURL),
            limit: maximumEntries
        )
        cachedEntries = entries

        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: logURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logger.error("Unable to persist local recording diagnostics; error=\((error as NSError).code, privacy: .public)")
        }
    }

    private func loadEntries(from url: URL) -> [RecordingDiagnosticEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RecordingDiagnosticEntry].self, from: data) else {
            return []
        }
        return Array(entries.suffix(maximumEntries))
    }
}
