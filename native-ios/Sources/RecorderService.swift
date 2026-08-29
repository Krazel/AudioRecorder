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
    @Published private(set) var isCapturingAudio = false

    private var engine = AVAudioEngine()
    private lazy var soundProcessor = SoundActivatedAudioProcessor { [weak self] progress in
        Task { @MainActor [weak self] in
            self?.applySoundProcessorProgress(progress)
        }
    }
    private var soundProcessorGeneration: UUID?
    private var audioRecorder: AVAudioRecorder?
    private var preparedSystemRecorder: AVAudioRecorder?
    private var recorderTimer: Timer?
    private var audioTapInstalled = false
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
    private var isPerformingRecovery = false
    private var waitingForMediaServicesReset = false
    private var expectedSystemRecorderEndUptime: TimeInterval?
    private var lastBackendActivityAt: Date?
    private var recoveryRetryTask: Task<Void, Never>?
    private var continuityPolicy = RecordingContinuityPolicy()
    private let diagnostics = RecordingDiagnostics()
    private var diagnosticSessionID = UUID()
    private let persistedRecordingIntentKey = "RecorderService.persistedRecordingIntent"

    var shouldResumePersistedRecording: Bool {
        UserDefaults.standard.bool(forKey: persistedRecordingIntentKey)
    }

    var activeRecordingMode: RecordingMode? {
        guard isRecording else { return nil }
        return currentSettings?.mode
    }

    func start(
        settings: RecordingSettingsStore,
        library: RecordingLibrary,
        uploadQueue: CloudUploadQueue
    ) async {
        guard !isRecording else { return }
        guard continuityPolicy.handle(.startRequested) == .startBackend else { return }
        diagnosticSessionID = UUID()
        settingsStore = settings
        self.library = library
        self.uploadQueue = uploadQueue
        currentSettings = RecordingSnapshot(settings)
        installEmergencySaveObserversIfNeeded()
        recordDiagnostic(.startRequested)

        do {
            try await requestMicrophonePermission()
            try configureAudioSession()
            try startNewSegment()
            try startRecordingBackend()
            isRecording = true
            isInterrupted = false
            isCapturingAudio = true
            cancelRecoveryRetry()
            persistRecordingIntent(true)
            lastError = nil
            _ = continuityPolicy.handle(.backendStarted)
            recordDiagnostic(.started)
        } catch {
            recordDiagnostic(.startFailed, error: error)
            _ = continuityPolicy.handle(.startFailed)
            stopRecordingSession(clearIntent: true, deactivateSession: true)
            lastError = error.localizedDescription
        }
    }

    func stop() {
        recordDiagnostic(.stopRequested)
        _ = continuityPolicy.handle(.stopRequested)
        stopRecordingSession(clearIntent: true, deactivateSession: true)
    }

    private func stopRecordingSession(clearIntent: Bool, deactivateSession: Bool) {
        shouldResumeAfterInterruption = false
        isInterrupted = false
        isPerformingRecovery = false
        waitingForMediaServicesReset = false
        cancelRecoveryRetry()
        if clearIntent {
            persistRecordingIntent(false)
        }
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
        if clearIntent {
            isRecording = false
        }
        isWritingAudio = false
        isCapturingAudio = false
    }

    func recoverActiveRecordingIfNeeded() async {
        guard isRecording, !waitingForMediaServicesReset, !isPerformingRecovery else { return }

        if shouldResumeAfterInterruption {
            await resumeAfterAudioInterruption()
            return
        }

        guard !hasActiveRecordingBackend else { return }
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reactivar la grabacion: %@"),
            rebuildAudioObjects: false
        )
    }


    private func requestMicrophonePermission() async throws {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return
            case .denied:
                throw RecorderError.microphoneDenied
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission {
                        continuation.resume(returning: $0)
                    }
                }
                if !granted {
                    throw RecorderError.microphoneDenied
                }
                return
            @unknown default:
                throw RecorderError.microphoneDenied
            }
        }

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
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker])
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
        guard let recorder = preparedSystemRecorder, let settings = currentSettings else {
            throw RecorderError.missingSettings
        }
        preparedSystemRecorder = nil
        guard recorder.record(forDuration: settings.segmentDuration) else {
            throw RecorderError.recorderStartFailed
        }

        audioRecorder = recorder
        expectedSystemRecorderEndUptime = ProcessInfo.processInfo.systemUptime + settings.segmentDuration
        lastBackendActivityAt = Date()
        isCapturingAudio = true
        isWritingAudio = true
        startBackendHealthTimer()
    }

    private func startBackendHealthTimer() {
        recorderTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackendHealth()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        recorderTimer = timer
    }

    private func updateBackendHealth() {
        guard isRecording, !isInterrupted, !isPerformingRecovery else { return }

        switch currentSettings?.mode {
        case .everything:
            updateSystemRecorderProgress()
        case .soundActivated:
            if !engine.isRunning {
                handleUnexpectedBackendFailure(
                    RecorderError.backendStoppedUnexpectedly,
                    diagnosticCode: .backendStoppedUnexpectedly
                )
            } else if let lastBackendActivityAt,
                      Date().timeIntervalSince(lastBackendActivityAt) > 5 {
                handleUnexpectedBackendFailure(
                    RecorderError.audioInputStalled,
                    diagnosticCode: .backendStoppedUnexpectedly
                )
            }
        case .none:
            break
        }
    }

    private func updateSystemRecorderProgress() {
        guard let recorder = audioRecorder else {
            handleUnexpectedBackendFailure(
                RecorderError.backendStoppedUnexpectedly,
                diagnosticCode: .backendStoppedUnexpectedly
            )
            return
        }

        guard recorder.isRecording else {
            let reachedExpectedLimit = expectedSystemRecorderEndUptime.map {
                ProcessInfo.processInfo.systemUptime >= $0 - 0.75
            } ?? false
            handleSystemRecorderFinished(
                recorder,
                successfully: reachedExpectedLimit,
                shouldRestart: true
            )
            return
        }

        recorder.updateMeters()
        currentLevel = recorder.averagePower(forChannel: 0)
        writtenDuration = recorder.currentTime
        elapsed = writtenDuration
        didWriteCurrentSegment = writtenDuration > 0.02
        lastBackendActivityAt = Date()
        setWritingAudio(true)

        if let settings = currentSettings, writtenDuration >= settings.segmentDuration + 1 {
            handleSystemRecorderFinished(recorder, successfully: true, shouldRestart: true)
        }
    }

    private func stopSystemRecorder(finalize: Bool) {
        recorderTimer?.invalidate()
        recorderTimer = nil
        expectedSystemRecorderEndUptime = nil
        preparedSystemRecorder = nil

        guard let recorder = audioRecorder else { return }
        let duration = recorder.currentTime
        audioRecorder = nil
        recorder.delegate = nil
        recorder.stop()
        isCapturingAudio = false

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
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            recordDiagnostic(.inputUnavailable)
            throw RecorderError.audioInputUnavailable
        }
        let processor = soundProcessor
        if audioTapInstalled {
            input.removeTap(onBus: 0)
            audioTapInstalled = false
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            processor.enqueue(buffer)
        }
        audioTapInstalled = true

        engine.prepare()
        try engine.start()
        lastBackendActivityAt = Date()
        isCapturingAudio = true
        startBackendHealthTimer()
    }

    private func stopEngine() {
        recorderTimer?.invalidate()
        recorderTimer = nil
        if audioTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            audioTapInstalled = false
        }
        engine.stop()
        let shouldApplyFinalProgress = soundProcessorGeneration != nil
        soundProcessorGeneration = nil
        let progress = soundProcessor.stop()
        if shouldApplyFinalProgress {
            applySoundProcessorState(progress)
        }
        isCapturingAudio = false
    }

    private func startNewSegment() throws {
        guard let settings = activeSettings else { throw RecorderError.missingSettings }
        let url = try RecordingStorage.nextSegmentURL(mode: settings.mode, quality: settings.quality)
        var preparedFile: AVAudioFile?
        var preparedRecorder: AVAudioRecorder?
        if settings.mode == .soundActivated {
            let inputFormat = engine.inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                throw RecorderError.audioInputUnavailable
            }
            preparedFile = try AVAudioFile(
                forWriting: url,
                settings: settings.quality.recordingSettings(matching: inputFormat)
            )
        } else {
            let recorder = try AVAudioRecorder(url: url, settings: settings.quality.recorderSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord() else {
                throw RecorderError.recorderPreparationFailed
            }
            preparedRecorder = recorder
        }

        // Commit only after the next destination is known to be writable. A
        // preparation failure must never discard or relabel the prior segment.
        completeCurrentSegment()
        currentSettings = settings
        currentFile = preparedFile
        preparedSystemRecorder = preparedRecorder
        currentURL = url
        currentSegmentStartedAt = Date()
        writtenDuration = 0
        didWriteCurrentSegment = false
        elapsed = 0
        isWritingAudio = settings.mode == .everything
    }

    private func rotateSegment() {
        guard continuityPolicy.handle(.segmentLimitReached) == .rotateSegment else { return }
        recordDiagnostic(.rotationRequested)
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
            isCapturingAudio = hasActiveRecordingBackend
            _ = continuityPolicy.handle(.nextSegmentStarted)
            cancelRecoveryRetry()
            lastError = nil
            recordDiagnostic(.rotationSucceeded)
        } catch {
            stopSystemRecorder(finalize: true)
            stopEngine()
            completeCurrentSegment()
            _ = continuityPolicy.handle(.nextSegmentFailed)
            recordDiagnostic(.rotationDeferred, error: error)
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription),
                error: error
            )
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.handleSystemRecorderFinished(recorder, successfully: flag, shouldRestart: true)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            let effectiveError = error ?? RecorderError.audioEncodingFailed
            self.recordDiagnostic(.audioWriteFailed, error: effectiveError)
            self.handleSystemRecorderFinished(recorder, successfully: false, shouldRestart: true)
        }
    }

    private func handleSystemRecorderFinished(_ recorder: AVAudioRecorder, successfully flag: Bool, shouldRestart: Bool) {
        guard audioRecorder === recorder else { return }

        recorderTimer?.invalidate()
        recorderTimer = nil
        expectedSystemRecorderEndUptime = nil
        audioRecorder = nil
        recorder.delegate = nil
        writtenDuration = max(writtenDuration, recorder.currentTime)
        didWriteCurrentSegment = didWriteCurrentSegment || writtenDuration > 0.02
        completeCurrentSegment()

        guard shouldRestart, isRecording, currentSettings?.mode == .everything else {
            isCapturingAudio = false
            setWritingAudio(false)
            return
        }

        if !flag {
            _ = continuityPolicy.handle(.backendFailed)
            let error = RecorderError.backendStoppedUnexpectedly
            recordDiagnostic(.backendStoppedUnexpectedly, error: error)
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription),
                error: error
            )
            return
        }

        do {
            recordDiagnostic(.rotationRequested)
            try configureAudioSession()
            try startNewSegment()
            try startSystemRecorder()
            isInterrupted = false
            _ = continuityPolicy.handle(.segmentLimitReached)
            _ = continuityPolicy.handle(.nextSegmentStarted)
            cancelRecoveryRetry()
            lastError = nil
            recordDiagnostic(.rotationSucceeded)
        } catch {
            _ = continuityPolicy.handle(.nextSegmentFailed)
            recordDiagnostic(.rotationDeferred, error: error)
            scheduleRecoveryRetry(
                message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription),
                error: error
            )
        }
    }

    private var activeSettings: RecordingSnapshot? {
        if let settingsStore {
            let configuredSettings = RecordingSnapshot(settingsStore)
            let resolvedMode = RecordingModeSessionPolicy.modeForNextSegment(
                configuredMode: configuredSettings.mode,
                activeMode: currentSettings?.mode,
                isRecording: isRecording
            )
            return configuredSettings.replacingMode(with: resolvedMode)
        }
        return currentSettings
    }

    private func applySoundProcessorProgress(_ progress: SoundActivatedAudioProgress) {
        guard progress.generation == soundProcessorGeneration else { return }
        lastBackendActivityAt = Date()
        applySoundProcessorState(progress)
        if let errorDescription = progress.errorDescription {
            let error = RecorderError.audioWriteFailed(errorDescription)
            recordDiagnostic(.audioWriteFailed, error: error)
            handleUnexpectedBackendFailure(error, diagnosticCode: .audioWriteFailed)
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
            currentSegmentStartedAt = nil
            writtenDuration = 0
            didWriteCurrentSegment = false
            elapsed = 0
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
        recordDiagnostic(.segmentCompleted)
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
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleAudioRouteChange(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMediaServicesLost()
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

    func applicationDidEnterBackground() {
        _ = continuityPolicy.handle(.enteredBackground)
        if isRecording {
            recordDiagnostic(.enteredBackground)
        }
    }

    func applicationDidBecomeActive() async {
        let action = continuityPolicy.handle(
            .enteredForeground(backendActive: hasActiveRecordingBackend)
        )
        if isRecording {
            recordDiagnostic(.enteredForeground)
        }
        if action == .recover {
            shouldResumeAfterInterruption = false
            await recoverRecordingBackend(
                messageFormat: L("No se pudo reactivar la grabacion: %@"),
                rebuildAudioObjects: false
            )
        }
    }

    private func handleMediaServicesLost() {
        guard isRecording else { return }
        waitingForMediaServicesReset = true
        isInterrupted = true
        isCapturingAudio = false
        setWritingAudio(false)
        cancelRecoveryRetry()
        _ = continuityPolicy.handle(.mediaServicesLost)
        recordDiagnostic(.mediaServicesLost)
    }

    private func recoverAfterMediaServicesReset() async {
        guard isRecording else { return }
        waitingForMediaServicesReset = false
        _ = continuityPolicy.handle(.mediaServicesReset)
        recordDiagnostic(.mediaServicesReset)
        await recoverRecordingBackend(
            messageFormat: L("No se pudo recuperar el audio del sistema: %@"),
            rebuildAudioObjects: true
        )
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
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            Task {
                await resumeAfterAudioInterruption(shouldResume: shouldResume)
            }
        @unknown default:
            break
        }
    }

    private func pauseForAudioInterruption() {
        guard isRecording else { return }
        guard continuityPolicy.handle(.interruptionBegan) == .pauseAndFinalize else { return }
        shouldResumeAfterInterruption = true
        isInterrupted = true
        isCapturingAudio = false
        setWritingAudio(false)
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        lastError = L("Grabacion pausada por otra app. Se reanudara sola.")
        recordDiagnostic(.interruptionBegan)
    }

    private func resumeAfterAudioInterruption(shouldResume: Bool = true) async {
        guard shouldResumeAfterInterruption, settingsStore != nil else { return }
        let action = continuityPolicy.handle(.interruptionEnded(shouldResume: shouldResume))
        if shouldResume {
            recordDiagnostic(.interruptionEndedResume)
        } else {
            recordDiagnostic(.interruptionEndedNoResume)
        }
        guard action == .recover else {
            // Apple treats shouldResume as a recommendation. Preserve the
            // session intent, but wait for a foreground/user-driven recovery.
            return
        }
        shouldResumeAfterInterruption = false
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reanudar la grabacion: %@"),
            rebuildAudioObjects: false
        )
    }

    private func handleAudioRouteChange(_ notification: Notification) async {
        guard isRecording,
              let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }

        let requiresRestart: Bool
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange, .noSuitableRouteForCategory:
            requiresRestart = true
        case .categoryChange, .override, .wakeFromSleep, .unknown:
            requiresRestart = false
        @unknown default:
            requiresRestart = true
        }

        recordDiagnostic(.routeChanged, detailCode: Int(rawReason))
        let action = continuityPolicy.handle(.routeChanged(requiresRestart: requiresRestart))
        guard action == .recover else {
            if !hasActiveRecordingBackend {
                await recoverActiveRecordingIfNeeded()
            }
            return
        }

        recordDiagnostic(.routeRecoveryStarted, detailCode: Int(rawReason))
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reactivar la grabacion: %@"),
            rebuildAudioObjects: currentSettings?.mode == .soundActivated
        )
    }

    private func handleUnexpectedBackendFailure(
        _ error: Error,
        diagnosticCode: RecordingDiagnosticCode
    ) {
        guard isRecording, !isInterrupted, !isPerformingRecovery else { return }
        _ = continuityPolicy.handle(.backendFailed)
        recordDiagnostic(diagnosticCode, error: error)
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        scheduleRecoveryRetry(
            message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription),
            error: error
        )
    }

    private func recoverRecordingBackend(
        messageFormat: String,
        rebuildAudioObjects: Bool
    ) async {
        guard isRecording, !isPerformingRecovery else { return }
        isPerformingRecovery = true
        defer { isPerformingRecovery = false }

        if rebuildAudioObjects {
            discardOrphanedAudioObjectsPreservingSegment()
        } else {
            stopSystemRecorder(finalize: true)
            stopEngine()
            completeCurrentSegment()
        }

        do {
            try configureAudioSession()
            try startNewSegment()
            try startRecordingBackend()
            isInterrupted = false
            isCapturingAudio = true
            shouldResumeAfterInterruption = false
            cancelRecoveryRetry()
            lastError = nil
            _ = continuityPolicy.handle(.recoverySucceeded)
            recordDiagnostic(.recoverySucceeded)
        } catch {
            isCapturingAudio = false
            _ = continuityPolicy.handle(.recoveryFailed)
            recordDiagnostic(.recoveryFailed, error: error)
            scheduleRecoveryRetry(
                message: String(format: messageFormat, error.localizedDescription),
                error: error
            )
        }
    }

    private func discardOrphanedAudioObjectsPreservingSegment() {
        recorderTimer?.invalidate()
        recorderTimer = nil
        expectedSystemRecorderEndUptime = nil
        audioRecorder?.delegate = nil
        audioRecorder = nil
        preparedSystemRecorder = nil
        audioTapInstalled = false
        engine = AVAudioEngine()

        let shouldApplyFinalProgress = soundProcessorGeneration != nil
        soundProcessorGeneration = nil
        let progress = soundProcessor.stop()
        if shouldApplyFinalProgress {
            applySoundProcessorState(progress)
        }
        currentFile = nil
        isCapturingAudio = false
        completeCurrentSegment()
    }

    private func scheduleRecoveryRetry(message: String, error: Error? = nil) {
        guard isRecording else { return }
        persistRecordingIntent(true)
        setWritingAudio(false)
        isCapturingAudio = false
        lastError = message
        recordDiagnostic(.recoveryScheduled, error: error)

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
            return engine.isRunning && soundProcessorGeneration != nil
        case .none:
            return false
        }
    }

    private func recordDiagnostic(
        _ code: RecordingDiagnosticCode,
        detailCode: Int? = nil,
        error: Error? = nil
    ) {
        diagnostics.record(
            code,
            sessionID: diagnosticSessionID,
            phase: continuityPolicy.phase,
            mode: currentSettings?.mode,
            detailCode: detailCode,
            error: error
        )
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        recordDiagnostic(.backendStoppedUnexpectedly)
        shouldResumeAfterInterruption = false
        isInterrupted = false
        cancelRecoveryRetry()
        stopSystemRecorder(finalize: true)
        stopEngine()
        completeCurrentSegment()
        isRecording = false
        isCapturingAudio = false
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

    private init(
        mode: RecordingMode,
        quality: AudioQuality,
        segmentDuration: TimeInterval,
        uploadState: UploadState,
        thresholdDB: Float,
        soundTailDuration: TimeInterval
    ) {
        self.mode = mode
        self.quality = quality
        self.segmentDuration = segmentDuration
        self.uploadState = uploadState
        self.thresholdDB = thresholdDB
        self.soundTailDuration = soundTailDuration
    }

    @MainActor
    init(_ settings: RecordingSettingsStore) {
        mode = settings.mode
        quality = settings.quality
        segmentDuration = settings.segmentDuration
        uploadState = settings.uploadAutomatically && settings.cloudProvider != .none ? .queued : .localOnly
        thresholdDB = settings.recordingThresholdDB
        soundTailDuration = settings.soundTailSeconds
    }

    func replacingMode(with mode: RecordingMode) -> RecordingSnapshot {
        RecordingSnapshot(
            mode: mode,
            quality: quality,
            segmentDuration: segmentDuration,
            uploadState: uploadState,
            thresholdDB: thresholdDB,
            soundTailDuration: soundTailDuration
        )
    }
}

enum RecorderError: LocalizedError {
    case microphoneDenied
    case missingSettings
    case recorderPreparationFailed
    case recorderStartFailed
    case backendStoppedUnexpectedly
    case audioInputUnavailable
    case audioInputStalled
    case audioEncodingFailed
    case audioWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            L("No hay permiso para usar el microfono.")
        case .missingSettings:
            L("Faltan ajustes de grabacion.")
        case .recorderPreparationFailed:
            L("No se pudo preparar el archivo de grabacion.")
        case .recorderStartFailed:
            L("No se pudo iniciar la grabacion.")
        case .backendStoppedUnexpectedly:
            L("La grabacion de audio se detuvo inesperadamente.")
        case .audioInputUnavailable:
            L("La entrada de audio no esta disponible.")
        case .audioInputStalled:
            L("La entrada de audio dejo de responder.")
        case .audioEncodingFailed:
            L("No se pudo codificar el audio.")
        case let .audioWriteFailed(description):
            description
        }
    }
}
