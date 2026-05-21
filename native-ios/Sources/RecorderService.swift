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
    @Published private(set) var isInterrupted = false

    private let engine = AVAudioEngine()
    private let analyzer = VoiceNoiseAnalyzer()
    private var currentFile: AVAudioFile?
    private var currentURL: URL?
    private var currentSettings: RecordingSnapshot?
    private var writtenDuration: TimeInterval = 0
    private var didWriteCurrentSegment = false
    private var installedObservers = false
    private var settingsStore: RecordingSettingsStore?
    private var library: RecordingLibrary?
    private var uploadQueue: CloudUploadQueue?
    private var shouldResumeAfterInterruption = false
    private var lastVisibleMeterUpdate = Date.distantPast

    func start(
        settings: RecordingSettingsStore,
        library: RecordingLibrary,
        uploadQueue: CloudUploadQueue
    ) async {
        guard !isRecording else { return }
        settingsStore = settings
        self.library = library
        self.uploadQueue = uploadQueue
        currentSettings = RecordingSnapshot(settings)
        installEmergencySaveObserversIfNeeded()

        do {
            try await requestMicrophonePermission()
            try configureAudioSession()
            try startNewSegment()
            try startEngine()
            isRecording = true
            isInterrupted = false
            lastError = nil
        } catch {
            stop()
            lastError = error.localizedDescription
        }
    }

    func stop() {
        shouldResumeAfterInterruption = false
        isInterrupted = false
        stopEngine()
        completeCurrentSegment()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.handle(buffer)
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func startNewSegment() throws {
        guard let currentSettings else { throw RecorderError.missingSettings }
        completeCurrentSegment()

        let url = try RecordingStorage.nextSegmentURL(mode: currentSettings.mode, quality: currentSettings.quality)
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        let file = try AVAudioFile(forWriting: url, settings: currentSettings.quality.recordingSettings(matching: inputFormat))
        currentFile = file
        currentURL = url
        currentSegmentStartedAt = Date()
        writtenDuration = 0
        didWriteCurrentSegment = false
        elapsed = 0
        isWritingAudio = currentSettings.mode == .everything
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
        guard let currentSettings else { return }
        let analysis = analyzer.analyze(buffer)
        publishLevelIfNeeded(analysis.rms)

        guard shouldWriteBuffer(analysis: analysis, settings: currentSettings) else {
            setWritingAudio(false)
            return
        }

        do {
            try currentFile?.write(from: buffer)
            let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
            writtenDuration += bufferDuration
            elapsed = writtenDuration
            didWriteCurrentSegment = true
            setWritingAudio(true)

            if writtenDuration >= currentSettings.segmentDuration {
                rotateSegment()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func publishLevelIfNeeded(_ level: Float) {
        let now = Date()
        guard now.timeIntervalSince(lastVisibleMeterUpdate) >= 0.25 else { return }
        currentLevel = level
        lastVisibleMeterUpdate = now
    }

    private func shouldWriteBuffer(analysis: VoiceNoiseAnalysis, settings: RecordingSnapshot) -> Bool {
        switch settings.mode {
        case .everything:
            return true
        case .soundActivated:
            return analysis.rms >= settings.thresholdDB
        }
    }

    private func setWritingAudio(_ value: Bool) {
        guard isWritingAudio != value else { return }
        isWritingAudio = value
    }

    private func completeCurrentSegment() {
        guard let url = currentURL, let startedAt = currentSegmentStartedAt, let currentSettings else {
            currentFile = nil
            currentURL = nil
            return
        }

        currentFile = nil
        let duration = writtenDuration
        guard didWriteCurrentSegment, duration > 0.02 else {
            deleteFileIfNeeded(url)
            currentURL = nil
            currentSegmentStartedAt = nil
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
            mode: currentSettings.mode,
            quality: currentSettings.quality,
            uploadState: currentSettings.uploadState,
            customName: nil
        )

        addCompletedSegment(item)
        currentURL = nil
        currentSegmentStartedAt = nil
        writtenDuration = 0
        didWriteCurrentSegment = false
    }

    private func addCompletedSegment(_ item: RecordingItem) {
        library?.addImmediately(item)
        guard settingsStore?.uploadAutomatically == true else { return }

        Task {
            await uploadQueue?.enqueue(
                recording: item,
                provider: settingsStore?.cloudProvider ?? .none,
                endpointURL: settingsStore?.cloudProvider == .customServer ? settingsStore?.customUploadEndpointURL : nil,
                authToken: settingsStore?.customUploadToken ?? ""
            )
            await uploadQueue?.processNext(library: library)
        }
    }

    private func deleteFileIfNeeded(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
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
            Task { @MainActor in
                self?.handleAudioInterruption(notification)
            }
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            pauseForAudioInterruption()
        case .ended:
            Task {
                await resumeAfterAudioInterruption()
            }
        @unknown default:
            break
        }
    }

    private func pauseForAudioInterruption() {
        guard isRecording else { return }
        shouldResumeAfterInterruption = true
        isInterrupted = true
        setWritingAudio(false)
        stopEngine()
        completeCurrentSegment()
        lastError = "Grabacion pausada por otra app. Se reanudara sola."
    }

    private func resumeAfterAudioInterruption() async {
        guard shouldResumeAfterInterruption, settingsStore != nil else { return }
        shouldResumeAfterInterruption = false

        do {
            try configureAudioSession()
            try startNewSegment()
            try startEngine()
            isRecording = true
            isInterrupted = false
            lastError = nil
        } catch {
            isInterrupted = false
            isRecording = false
            setWritingAudio(false)
            lastError = "No se pudo reanudar la grabacion: \(error.localizedDescription)"
        }
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        shouldResumeAfterInterruption = false
        isInterrupted = false
        stopEngine()
        completeCurrentSegment()
        isRecording = false
        setWritingAudio(false)
    }
}

private struct RecordingSnapshot {
    let mode: RecordingMode
    let quality: AudioQuality
    let segmentDuration: TimeInterval
    let uploadState: UploadState
    let thresholdDB: Float

    @MainActor
    init(_ settings: RecordingSettingsStore) {
        mode = settings.mode
        quality = settings.quality
        segmentDuration = settings.segmentDuration
        uploadState = settings.uploadAutomatically && settings.cloudProvider != .none ? .queued : .localOnly
        thresholdDB = settings.recordingThresholdDB
    }
}

enum RecorderError: LocalizedError {
    case microphoneDenied
    case missingSettings

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "No hay permiso para usar el microfono."
        case .missingSettings:
            "Faltan ajustes de grabacion."
        }
    }
}
