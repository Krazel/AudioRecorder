import Foundation

enum RecordingProcessIdentity {
    /// One identifier per process launch, shared by any recreated SwiftUI
    /// object graph in that same process.
    static let current = UUID()
}

struct RecordingExecutionSnapshot: Codable, Equatable {
    let processID: UUID
    let sessionID: UUID
    let startedAt: Date
    var lastAudioActivityAt: Date
    var lastSegmentCommittedAt: Date?
    var receivedTerminationNotification: Bool
}

enum PreviousRecordingExecutionAssessment: Equatable {
    case none
    case endedWithoutStop(secondsSinceLastAudioActivity: Int, receivedTerminationNotification: Bool)
}

enum RecordingExecutionAssessmentPolicy {
    static func assess(
        _ snapshot: RecordingExecutionSnapshot?,
        persistedRecordingIntent: Bool,
        currentProcessID: UUID,
        now: Date
    ) -> PreviousRecordingExecutionAssessment {
        guard persistedRecordingIntent,
              let snapshot,
              snapshot.processID != currentProcessID else {
            return .none
        }

        let age = max(0, Int(now.timeIntervalSince(snapshot.lastAudioActivityAt)))
        return .endedWithoutStop(
            secondsSinceLastAudioActivity: age,
            receivedTerminationNotification: snapshot.receivedTerminationNotification
        )
    }
}

/// A tiny local journal for distinguishing a backend stall from a process that
/// disappeared without Stop. It stores only random run IDs and timestamps.
/// No audio, file path, device, route, account, or user-entered content exists
/// in this journal.
final class RecordingExecutionLedger: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private let minimumHeartbeatWriteInterval: TimeInterval
    private var snapshot: RecordingExecutionSnapshot?

    init(
        url: URL = RecordingExecutionLedger.defaultURL,
        minimumHeartbeatWriteInterval: TimeInterval = 10
    ) {
        self.url = url
        self.minimumHeartbeatWriteInterval = minimumHeartbeatWriteInterval
        snapshot = Self.load(from: url)
    }

    func assessment(
        persistedRecordingIntent: Bool,
        currentProcessID: UUID,
        now: Date = Date()
    ) -> PreviousRecordingExecutionAssessment {
        lock.lock()
        defer { lock.unlock() }
        return RecordingExecutionAssessmentPolicy.assess(
            snapshot,
            persistedRecordingIntent: persistedRecordingIntent,
            currentProcessID: currentProcessID,
            now: now
        )
    }

    func begin(processID: UUID, sessionID: UUID, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        snapshot = RecordingExecutionSnapshot(
            processID: processID,
            sessionID: sessionID,
            startedAt: date,
            lastAudioActivityAt: date,
            lastSegmentCommittedAt: nil,
            receivedTerminationNotification: false
        )
        persistLocked()
    }

    func heartbeat(at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard var snapshot,
              date.timeIntervalSince(snapshot.lastAudioActivityAt) >= minimumHeartbeatWriteInterval else {
            return
        }
        snapshot.lastAudioActivityAt = date
        self.snapshot = snapshot
        persistLocked()
    }

    func markSegmentCommitted(at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard var snapshot else { return }
        snapshot.lastSegmentCommittedAt = date
        self.snapshot = snapshot
        persistLocked()
    }

    func markTerminationNotification() {
        lock.lock()
        defer { lock.unlock() }
        guard var snapshot else { return }
        snapshot.receivedTerminationNotification = true
        self.snapshot = snapshot
        persistLocked()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        snapshot = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func persistLocked() {
        guard let snapshot else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            // Recording must not fail merely because optional local diagnostics
            // could not be persisted.
        }
    }

    private static func load(from url: URL) -> RecordingExecutionSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RecordingExecutionSnapshot.self, from: data)
    }

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("RecordingRuntime", isDirectory: true)
            .appendingPathComponent("active-execution.json")
    }
}

enum RecordingAudioActivityPolicy {
    static func isFresh(lastActivityAt: Date?, now: Date, timeout: TimeInterval) -> Bool {
        guard let lastActivityAt else { return false }
        return now.timeIntervalSince(lastActivityAt) <= timeout
    }
}

/// Watches activity produced by the audio-processing queue itself. Unlike a
/// Timer attached to RunLoop.main, this does not depend on the SwiftUI/main
/// run loop continuing to advance while the app records in background.
final class RecordingAudioActivityWatchdog: @unchecked Sendable {
    typealias TimeoutHandler = @Sendable (UUID) -> Void

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.dmkr.audio.recording-watchdog", qos: .userInitiated)
    private let timeout: TimeInterval
    private var handler: TimeoutHandler?
    private var timer: DispatchSourceTimer?
    private var generation: UUID?
    private var lastActivityAt: Date?
    private var didSignalTimeout = false

    init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    func start(
        generation: UUID,
        at date: Date = Date(),
        handler: @escaping TimeoutHandler
    ) {
        stop()
        lock.lock()
        self.generation = generation
        lastActivityAt = date
        didSignalTimeout = false
        self.handler = handler
        lock.unlock()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.checkForTimeout()
        }
        lock.lock()
        self.timer = timer
        lock.unlock()
        timer.resume()
    }

    func heartbeat(generation: UUID?, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == self.generation else { return }
        lastActivityAt = date
        didSignalTimeout = false
    }

    func isFresh(generation: UUID?, at date: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard generation == self.generation else { return false }
        return RecordingAudioActivityPolicy.isFresh(
            lastActivityAt: lastActivityAt,
            now: date,
            timeout: timeout
        )
    }

    func stop() {
        lock.lock()
        let timer = self.timer
        self.timer = nil
        generation = nil
        lastActivityAt = nil
        didSignalTimeout = false
        handler = nil
        lock.unlock()
        timer?.setEventHandler {}
        timer?.cancel()
    }

    private func checkForTimeout(now: Date = Date()) {
        lock.lock()
        guard let generation,
              !didSignalTimeout,
              !RecordingAudioActivityPolicy.isFresh(
                lastActivityAt: lastActivityAt,
                now: now,
                timeout: timeout
              ) else {
            lock.unlock()
            return
        }
        didSignalTimeout = true
        let handler = self.handler
        lock.unlock()
        handler?(generation)
    }
}

final class RecordingLivenessBridge: @unchecked Sendable {
    let watchdog: RecordingAudioActivityWatchdog
    let ledger: RecordingExecutionLedger

    init(
        watchdog: RecordingAudioActivityWatchdog = RecordingAudioActivityWatchdog(),
        ledger: RecordingExecutionLedger = RecordingExecutionLedger()
    ) {
        self.watchdog = watchdog
        self.ledger = ledger
    }

    func observedAudioActivity(generation: UUID?) {
        watchdog.heartbeat(generation: generation)
        ledger.heartbeat()
    }
}
