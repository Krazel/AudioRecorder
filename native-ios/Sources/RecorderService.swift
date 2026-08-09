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

    private let engine = AVAudioEngine()
    private lazy var soundProcessor = SoundActivatedAudioProcessor { [weak self] progress in
        Task { @MainActor [weak self] in
            self?.applySoundProcessorProgress(progress)
        }
    }
    private var soundProcessorGeneration: UUID?
    private var audioRecorder: AVAudioRecorder?
    private var recorderTimer: Timer?
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
    private var recoveryRetryTask: Task<Void, Never>?
    private let persistedRecordingIntentKey = "RecorderService.persistedRecordingIntent"

    var shouldResumePersistedRecording: Bool {
        UserDefaults.standard.bool(forKey: persistedRecordingIntentKey)
    }

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
            try startRecordingBackend()
            isRecording = true
            isInterrupted = false
            cancelRecoveryRetry()
            persistRecordingIntent(true)
            lastError = nil
        } catch {
            stop()
            lastError = error.localizedDescription
        }
    }

    func stop() {
        shouldResumeAfterInterruption = false
        isInterrupted = false
        cancelRecoveryRetry()
        persistRecordingIntent(false)
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRecording = false
        isWritingAudio = false
    }

    func recoverActiveRecordingIfNeeded() async {
        guard isRecording else { return }

        if shouldResumeAfterInterruption {
            await resumeAfterAudioInterruption()
            return
        }

        if currentSettings?.mode == .everything || activeSettings?.mode == .everything {
            guard audioRecorder?.isRecording != true else { return }

            do {
                stopSystemRecorder(finalize: true)
                completeCurrentSegment()
                try configureAudioSession()
                try startNewSegment()
                try startSystemRecorder()
                isInterrupted = false
                cancelRecoveryRetry()
                lastError = nil
            } catch {
                scheduleRecoveryRetry(
                    message: String(format: L("No se pudo reactivar la grabacion: %@"), error.localizedDescription)
                )
            }
            return
        }

        guard !engine.isRunning else { return }

        do {
            try configureAudioSession()
            if currentFile == nil {
                try startNewSegment()
            }
            try startEngine()
            isInterrupted = false
            cancelRecoveryRetry()
            lastError = nil
        } catch {
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reactivar la grabacion: %@"), error.localizedDescription)
            )
        }
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
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }

    private func startRecordingBackend() throws {
        guard let settings = currentSettings else { throw RecorderError.missingSettings }
        switch settings.mode {
        case .everything:
            try startSystemRecorder()
        case .soundActivated:
            try startEngine()
        }
    }

    private func startSystemRecorder() throws {
        guard let url = currentURL, let settings = currentSettings else {
            throw RecorderError.missingSettings
        }

        let recorder = try AVAudioRecorder(url: url, settings: settings.quality.recorderSettings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record(forDuration: settings.segmentDuration) else {
            throw RecorderError.recorderStartFailed
        }

        audioRecorder = recorder
        isWritingAudio = true
        startSystemRecorderTimer()
    }

    private func startSystemRecorderTimer() {
        recorderTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemRecorderProgress()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        recorderTimer = timer
    }

    private func updateSystemRecorderProgress() {
        guard let recorder = audioRecorder else { return }

        guard recorder.isRecording else {
            handleSystemRecorderFinished(recorder, successfully: true, shouldRestart: true)
            return
        }

        recorder.updateMeters()
        currentLevel = recorder.averagePower(forChannel: 0)
        writtenDuration = recorder.currentTime
        elapsed = writtenDuration
        didWriteCurrentSegment = writtenDuration > 0.02
        setWritingAudio(true)

        if let settings = currentSettings, writtenDuration >= settings.segmentDuration + 1 {
            handleSystemRecorderFinished(recorder, successfully: true, shouldRestart: true)
        }
    }

    private func stopSystemRecorder(finalize: Bool) {
        recorderTimer?.invalidate()
        recorderTimer = nil

        guard let recorder = audioRecorder else { return }
        let duration = recorder.currentTime
        audioRecorder = nil
        recorder.delegate = nil
        recorder.stop()

        guard finalize else { return }
        writtenDuration = max(writtenDuration, duration)
        didWriteCurrentSegment = didWriteCurrentSegment || writtenDuration > 0.02
    }

    private func startEngine() throws {
        guard let currentFile, let settings = currentSettings else {
            throw RecorderError.missingSettings
        }
        if soundProcessorGeneration == nil {
            soundProcessorGeneration = soundProcessor.start(
                file: currentFile,
                settings: SoundActivatedAudioSettings(
                    segmentDuration: settings.segmentDuration,
                    thresholdDB: settings.thresholdDB,
                    soundTailDuration: settings.soundTailDuration
                )
            )
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let processor = soundProcessor
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            processor.enqueue(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let shouldApplyFinalProgress = soundProcessorGeneration != nil
        soundProcessorGeneration = nil
        let progress = soundProcessor.stop()
        if shouldApplyFinalProgress {
            applySoundProcessorState(progress)
        }
    }

    private func startNewSegment() throws {
        guard let settings = activeSettings else { throw RecorderError.missingSettings }
        completeCurrentSegment()

        currentSettings = settings
        let url = try RecordingStorage.nextSegmentURL(mode: settings.mode, quality: settings.quality)
        if settings.mode == .soundActivated {
            let inputFormat = engine.inputNode.outputFormat(forBus: 0)
            let file = try AVAudioFile(forWriting: url, settings: settings.quality.recordingSettings(matching: inputFormat))
            currentFile = file
        } else {
            currentFile = nil
        }
        currentURL = url
        currentSegmentStartedAt = Date()
        writtenDuration = 0
        didWriteCurrentSegment = false
        elapsed = 0
        isWritingAudio = settings.mode == .everything
    }

    private func rotateSegment() {
        do {
            if currentSettings?.mode == .everything {
                stopSystemRecorder(finalize: true)
            }
            try startNewSegment()
            if currentSettings?.mode == .everything {
                try startSystemRecorder()
            } else if currentSettings?.mode == .soundActivated,
                      let currentFile,
                      let settings = currentSettings {
                soundProcessorGeneration = soundProcessor.start(
                    file: currentFile,
                    settings: SoundActivatedAudioSettings(
                        segmentDuration: settings.segmentDuration,
                        thresholdDB: settings.thresholdDB,
                        soundTailDuration: settings.soundTailDuration
                    )
                )
            }
        } catch {
            lastError = error.localizedDescription
            stop()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.handleSystemRecorderFinished(recorder, successfully: flag, shouldRestart: true)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
            }
            self.handleSystemRecorderFinished(recorder, successfully: false, shouldRestart: true)
        }
    }

    private func handleSystemRecorderFinished(_ recorder: AVAudioRecorder, successfully flag: Bool, shouldRestart: Bool) {
        guard audioRecorder === recorder else { return }

        recorderTimer?.invalidate()
        recorderTimer = nil
        audioRecorder = nil
        recorder.delegate = nil
        writtenDuration = max(writtenDuration, recorder.currentTime)
        didWriteCurrentSegment = didWriteCurrentSegment || writtenDuration > 0.02
        completeCurrentSegment()

        guard shouldRestart, isRecording, currentSettings?.mode == .everything else {
            setWritingAudio(false)
            return
        }

        do {
            try configureAudioSession()
            try startNewSegment()
            try startSystemRecorder()
            isInterrupted = false
            if flag {
                cancelRecoveryRetry()
                lastError = nil
            }
        } catch {
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription)
            )
        }
    }

    private var activeSettings: RecordingSnapshot? {
        if let settingsStore {
            return RecordingSnapshot(settingsStore)
        }
        return currentSettings
    }

    private func applySoundProcessorProgress(_ progress: SoundActivatedAudioProgress) {
        guard progress.generation == soundProcessorGeneration else { return }
        applySoundProcessorState(progress)
        if let errorDescription = progress.errorDescription {
            lastError = errorDescription
            stop()
            return
        }
        if progress.reachedSegmentLimit, isRecording, currentSettings?.mode == .soundActivated {
            rotateSegment()
        }
    }

    private func applySoundProcessorState(_ progress: SoundActivatedAudioProgress) {
        if let level = progress.level {
            currentLevel = level
        }
        writtenDuration = progress.writtenDuration
        elapsed = progress.writtenDuration
        didWriteCurrentSegment = progress.didWrite
        setWritingAudio(progress.isWriting)
    }

    private func setWritingAudio(_ value: Bool) {
        guard isWritingAudio != value else { return }
        isWritingAudio = value
    }

    private func persistRecordingIntent(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: persistedRecordingIntentKey)
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
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.recoverActiveRecordingIfNeeded()
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

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.recoverActiveRecordingIfNeeded()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.recoverAfterMediaServicesReset()
            }
        }
    }

    private func recoverAfterMediaServicesReset() async {
        guard isRecording else { return }
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        currentFile = nil
        currentURL = nil
        currentSegmentStartedAt = nil

        do {
            try configureAudioSession()
            try startNewSegment()
            try startRecordingBackend()
            isInterrupted = false
            cancelRecoveryRetry()
            lastError = nil
        } catch {
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo recuperar el audio del sistema: %@"), error.localizedDescription)
            )
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
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        lastError = L("Grabacion pausada por otra app. Se reanudara sola.")
    }

    private func resumeAfterAudioInterruption() async {
        guard shouldResumeAfterInterruption, settingsStore != nil else { return }
        shouldResumeAfterInterruption = false

        do {
            try configureAudioSession()
            try startNewSegment()
            try startRecordingBackend()
            isRecording = true
            isInterrupted = false
            cancelRecoveryRetry()
            lastError = nil
        } catch {
            isInterrupted = false
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription)
            )
        }
    }

    private func scheduleRecoveryRetry(message: String) {
        guard isRecording else { return }
        persistRecordingIntent(true)
        setWritingAudio(false)
        lastError = message

        guard recoveryRetryTask == nil else { return }
        recoveryRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await self?.runScheduledRecoveryRetry()
        }
    }

    private func runScheduledRecoveryRetry() async {
        recoveryRetryTask = nil
        guard isRecording else { return }
        await recoverActiveRecordingIfNeeded()

        if isRecording, !hasActiveRecordingBackend {
            scheduleRecoveryRetry(message: lastError ?? L("No se pudo reanudar la grabacion."))
        }
    }

    private func cancelRecoveryRetry() {
        recoveryRetryTask?.cancel()
        recoveryRetryTask = nil
    }

    private var hasActiveRecordingBackend: Bool {
        switch currentSettings?.mode ?? activeSettings?.mode {
        case .everything:
            return audioRecorder?.isRecording == true
        case .soundActivated:
            return engine.isRunning
        case .none:
            return false
        }
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        shouldResumeAfterInterruption = false
        isInterrupted = false
        cancelRecoveryRetry()
        stopSystemRecorder(finalize: true)
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
    let soundTailDuration: TimeInterval

    @MainActor
    init(_ settings: RecordingSettingsStore) {
        mode = settings.mode
        quality = settings.quality
        segmentDuration = settings.segmentDuration
        uploadState = settings.uploadAutomatically && settings.cloudProvider != .none ? .queued : .localOnly
        thresholdDB = settings.recordingThresholdDB
        soundTailDuration = settings.soundTailSeconds
    }
}

enum RecorderError: LocalizedError {
    case microphoneDenied
    case missingSettings
    case recorderStartFailed

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            L("No hay permiso para usar el microfono.")
        case .missingSettings:
            L("Faltan ajustes de grabacion.")
        case .recorderStartFailed:
            L("No se pudo iniciar la grabacion.")
        }
    }
}
