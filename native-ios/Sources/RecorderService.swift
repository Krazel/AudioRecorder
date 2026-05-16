import AVFoundation
import Foundation
import UIKit

@MainActor
final class RecorderService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var currentSegmentStartedAt: Date?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published private(set) var currentLevel: Float = -120
    @Published private(set) var isWritingAudio = false

    private let engine = AVAudioEngine()
    private let analyzer = VoiceNoiseAnalyzer()
    private var currentFile: AVAudioFile?
    private var currentURL: URL?
    private var writtenDuration: TimeInterval = 0
    private var didWriteCurrentSegment = false
    private var installedObservers = false
    private var settings: RecordingSettingsStore?
    private var library: RecordingLibrary?
    private var uploadQueue: CloudUploadQueue?

    func start(
        settings: RecordingSettingsStore,
        library: RecordingLibrary,
        uploadQueue: CloudUploadQueue
    ) async {
        guard !isRecording else { return }
        self.settings = settings
        self.library = library
        self.uploadQueue = uploadQueue
        installEmergencySaveObserversIfNeeded()

        do {
            try await requestMicrophonePermission()
            try configureAudioSession()
            try startNewSegment()
            try startEngine()
            isRecording = true
            lastError = nil
        } catch {
            stop()
            lastError = error.localizedDescription
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        completeCurrentSegment()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
        isWritingAudio = false
    }

    private func requestMicrophonePermission() async throws {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return
        case .denied:
            throw RecorderError.microphoneDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if !granted {
                throw RecorderError.microphoneDenied
            }
        @unknown default:
            throw RecorderError.microphoneDenied
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.handle(buffer)
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func startNewSegment() throws {
        guard let settings else { throw RecorderError.missingSettings }
        completeCurrentSegment()

        let url = try RecordingStorage.nextSegmentURL(mode: settings.mode, quality: settings.quality)
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        let file = try AVAudioFile(forWriting: url, settings: settings.quality.recordingSettings(matching: inputFormat))
        currentFile = file
        currentURL = url
        currentSegmentStartedAt = Date()
        writtenDuration = 0
        didWriteCurrentSegment = false
        elapsed = 0
    }

    private func rotateSegment() {
        do {
            try startNewSegment()
        } catch {
            lastError = error.localizedDescription
            stop()
        }
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        let analysis = analyzer.analyze(buffer)
        currentLevel = analysis.rms

        guard shouldWriteBuffer(analysis: analysis) else {
            isWritingAudio = false
            return
        }

        do {
            try currentFile?.write(from: buffer)
            let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
            writtenDuration += bufferDuration
            elapsed = writtenDuration
            didWriteCurrentSegment = true
            isWritingAudio = true
            if let settings, writtenDuration >= settings.segmentDuration {
                rotateSegment()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func shouldWriteBuffer(analysis: VoiceNoiseAnalysis) -> Bool {
        guard let settings else { return true }
        switch settings.mode {
        case .everything:
            return true
        case .soundActivated:
            return analysis.rms >= settings.recordingThresholdDB
        }
    }

    private func completeCurrentSegment() {
        guard let url = currentURL, let startedAt = currentSegmentStartedAt else {
            currentFile = nil
            currentURL = nil
            return
        }

        currentFile = nil
        let duration = writtenDuration
        guard didWriteCurrentSegment, duration > 0.02, let settings else {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            currentURL = nil
            writtenDuration = 0
            didWriteCurrentSegment = false
            elapsed = 0
            return
        }

        let item = RecordingItem(
            id: UUID(),
            createdAt: startedAt,
            duration: duration,
            fileURL: url,
            mode: settings.mode,
            quality: settings.quality,
            uploadState: settings.uploadAutomatically && settings.cloudProvider != .none ? .queued : .localOnly,
            customName: nil
        )

        library?.addImmediately(item)
        if settings.uploadAutomatically {
            Task {
                await uploadQueue?.enqueue(recording: item, provider: settings.cloudProvider)
                await uploadQueue?.processNext()
            }
        }

        currentFile = nil
        currentURL = nil
        writtenDuration = 0
        didWriteCurrentSegment = false
    }

    private func installEmergencySaveObserversIfNeeded() {
        guard !installedObservers else { return }
        installedObservers = true

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.emergencyStopAndSave()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .began else {
                return
            }
            Task { @MainActor in
                self?.emergencyStopAndSave()
            }
        }
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        completeCurrentSegment()
        isRecording = false
        isWritingAudio = false
    }
}

enum RecorderError: LocalizedError {
    case microphoneDenied
    case missingSettings

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "No hay permiso para usar el micrófono."
        case .missingSettings:
            "Faltan ajustes de grabación."
        }
    }
}
