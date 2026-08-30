import Foundation
import OSLog

enum InternalRecordingDiagnosticsAvailability {
    private static let googleDemoAppID = "ca-app-pub-3940256099942544~1458002511"

    static func isEnabled(adMobAppID: String?) -> Bool {
        adMobAppID == googleDemoAppID
    }

    static var isEnabledForCurrentBuild: Bool {
        isEnabled(
            adMobAppID: Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        )
    }
}

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
    case systemAlertInterruptionPreferenceUnavailable
    case audioEngineConfigurationChanged
    case audioEngineRebuilt
    case routeChanged
    case routeRecoveryStarted
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

struct RecordingDiagnosticRuntimeState: Codable, Equatable {
    let recordingIntent: Bool
    let engineRunning: Bool
    let inputSampleRate: Double
    let inputChannelCount: Int
    let interrupted: Bool
    let recovering: Bool
    let retryScheduled: Bool
}

struct RecordingDiagnosticEntry: Codable, Equatable {
    let timestamp: Date
    let sessionID: UUID
    let code: RecordingDiagnosticCode
    let phase: String
    let mode: String?
    let detailCode: Int?
    let interruptionType: Int?
    let interruptionOptions: Int?
    let interruptionReason: Int?
    let interruptionWasSuspended: Bool?
    let recoveryStage: String?
    let errorDomain: String?
    let errorCode: Int?
    let runtime: RecordingDiagnosticRuntimeState
}

struct RecordingDiagnosticExportDocument: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: Date
    let appVersion: String
    let buildNumber: String
    let operatingSystemVersion: String
    let entries: [RecordingDiagnosticEntry]
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
        interruptionType: Int? = nil,
        interruptionOptions: Int? = nil,
        interruptionReason: Int? = nil,
        interruptionWasSuspended: Bool? = nil,
        recoveryStage: RecordingRecoveryStage? = nil,
        error: Error? = nil,
        runtime: RecordingDiagnosticRuntimeState
    ) {
        let nsError = error.map { $0 as NSError }
        let entry = RecordingDiagnosticEntry(
            timestamp: Date(),
            sessionID: sessionID,
            code: code,
            phase: String(describing: phase),
            mode: mode?.rawValue,
            detailCode: detailCode,
            interruptionType: interruptionType,
            interruptionOptions: interruptionOptions,
            interruptionReason: interruptionReason,
            interruptionWasSuspended: interruptionWasSuspended,
            recoveryStage: recoveryStage?.rawValue,
            errorDomain: nsError?.domain,
            errorCode: nsError?.code,
            runtime: runtime
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

    func makeExportFile(generatedAt: Date = Date()) throws -> URL {
        let entries: [RecordingDiagnosticEntry]
        if let cachedEntries {
            entries = cachedEntries
        } else if let logURL {
            entries = loadEntries(from: logURL)
        } else {
            entries = []
        }
        let document = RecordingDiagnosticExportDocument(
            schemaVersion: 1,
            generatedAt: generatedAt,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            entries: Array(entries.suffix(maximumEntries))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-recorder-recording-diagnostics.json")
        try data.write(
            to: exportURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        return exportURL
    }

    private func loadEntries(from url: URL) -> [RecordingDiagnosticEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RecordingDiagnosticEntry].self, from: data) else {
            return []
        }
        return Array(entries.suffix(maximumEntries))
    }
}
