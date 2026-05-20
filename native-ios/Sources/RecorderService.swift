import AVFoundation
import Foundation
import UIKit

@MainActor
final class RecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var currentSegmentStartedAt: Date?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published private(set) var currentLevel: Float = -120
    @Published private(set) var isWritingAudio = false
    @Published private(set) var isInterrupted = false

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var currentSettings: RecordingSnapshot?
    private var meterTimer: Timer?
    private var installedObservers = false
    private var settingsStore: RecordingSettingsStore?
    private var library: RecordingLibrary?
    private var uploadQueue: CloudUploadQueue?
    private var shouldResumeAfterInterruption = false
    private var detectedSoundInCurrentSegment = false

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
            startMetering()
            isRecording = true
            lastError = nil
        } catch {
            stop()
            lastError = error.localizedDescription
        }
    }

    func stop() {
        shouldResumeAfterInterruption = false
        isInterrupted = false
        stopMetering()
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

    private func startNewSegment() throws {
        guard let currentSettings else { throw RecorderError.missingSettings }

        let url = try RecordingStorage.nextSegmentURL(mode: currentSettings.mode, quality: currentSettings.quality)
        let recorder = try AVAudioRecorder(url: url, settings: currentSettings.quality.recorderSettings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        currentURL = url
        currentSegmentStartedAt = Date()
        elapsed = 0
        currentLevel = -120
        detectedSoundInCurrentSegment = currentSettings.mode == .everything
        isWritingAudio = currentSettings.mode == .everything
    }

    private func rotateSegment() {
        completeCurrentSegment()
        do {
            try startNewSegment()
        } catch {
            lastError = error.localizedDescription
            stop()
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickMeter()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func tickMeter() {
        guard let recorder, let currentSettings else { return }
        recorder.updateMeters()

        let level = recorder.averagePower(forChannel: 0)
        currentLevel = level
        elapsed = recorder.currentTime

        switch currentSettings.mode {
        case .everything:
            isWritingAudio = true
        case .soundActivated:
            let detected = level >= currentSettings.thresholdDB
            detectedSoundInCurrentSegment = detectedSoundInCurrentSegment || detected
            isWritingAudio = detected
        }

        if recorder.currentTime >= currentSettings.segmentDuration {
            rotateSegment()
        }
    }

    private func completeCurrentSegment() {
        guard let recorder, let url = currentURL, let startedAt = currentSegmentStartedAt, let currentSettings else {
            self.recorder = nil
            currentURL = nil
            return
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil

        guard duration > 0.02, detectedSoundInCurrentSegment else {
            deleteFileIfNeeded(url)
            currentURL = nil
            currentSegmentStartedAt = nil
            elapsed = 0
            detectedSoundInCurrentSegment = false
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
        detectedSoundInCurrentSegment = false
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
        isWritingAudio = false
        stopMetering()
        completeCurrentSegment()
        lastError = "Grabacion pausada por otra app. Se reanudara sola."
    }

    private func resumeAfterAudioInterruption() async {
        guard shouldResumeAfterInterruption, settingsStore != nil else { return }
        shouldResumeAfterInterruption = false

        do {
            try configureAudioSession()
            try startNewSegment()
            startMetering()
            isRecording = true
            isInterrupted = false
            lastError = nil
        } catch {
            isInterrupted = false
            isRecording = false
            isWritingAudio = false
            lastError = "No se pudo reanudar la grabacion: \(error.localizedDescription)"
        }
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        shouldResumeAfterInterruption = false
        isInterrupted = false
        stopMetering()
        completeCurrentSegment()
        isRecording = false
        isWritingAudio = false
    }
}

private struct RecordingSnapshot {
    let mode: RecordingMode
    let quality: AudioQuality
    let segmentDuration: TimeInterval
    let uploadState: UploadState
    let thresholdDB: Float

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
