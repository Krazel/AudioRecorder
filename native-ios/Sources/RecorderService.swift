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
    @Published private(set) var isCapturingAudio = false

    private var engine = AVAudioEngine()
    private lazy var soundProcessor = SoundActivatedAudioProcessor { [weak self] progress in
        Task { @MainActor [weak self] in
            self?.applySoundProcessorProgress(progress)
        }
    }
    private var soundProcessorGeneration: UUID?
    private var recorderTimer: Timer?
    private var audioTapInstalled = false
    private var currentFile: AVAudioFile?
    private var currentURL: URL?
    private var currentSegmentCompletionToken: UUID?
    private var segmentCompletionGate = RecordingSegmentCompletionGate()
    private var currentSettings: RecordingSnapshot?
    private var writtenDuration: TimeInterval = 0
    private var didWriteCurrentSegment = false
    private var installedObservers = false
    private var settingsStore: RecordingSettingsStore?
    private var library: RecordingLibrary?
    private var uploadQueue: CloudUploadQueue?
    private var isPerformingRecovery = false
    private var waitingForMediaServicesReset = false
    private var lastBackendActivityAt: Date?
    private var recoveryRetryTask: Task<Void, Never>?
    private var recoveryRetryToken: UUID?
    private var segmentRotationRetryTask: Task<Void, Never>?
    private var continuityPolicy = RecordingContinuityPolicy()
    private var recoveryDriver = RecordingRecoveryDriver()
    private var currentAudioEngineGeneration = 0
    private var lastObservedInputSampleRate: Double = 0
    private var lastObservedInputChannelCount = 0
    private var recoveryInvalidationGate = RecordingRecoveryInvalidationGate()
    private var recoveryMustAbandonEngine = false
    private var awaitingFirstRecoveredBuffer = false
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

    func makeRecordingDiagnosticsExport() throws -> URL {
        try diagnostics.makeExportFile()
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
        isInterrupted = false
        isPerformingRecovery = false
        awaitingFirstRecoveredBuffer = false
        waitingForMediaServicesReset = false
        cancelRecoveryRetry()
        cancelSegmentRotationRetry()
        if clearIntent {
            persistRecordingIntent(false)
        }
        if recoveryMustAbandonEngine {
            abandonAudioObjectsPreservingSegment()
        } else {
            stopEngine()
            completeCurrentSegment()
        }
        recoveryMustAbandonEngine = false
        if deactivateSession {
            let session = AVAudioSession.sharedInstance()
            try? session.setPrefersNoInterruptionsFromSystemAlerts(false)
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        }
        if clearIntent {
            isRecording = false
        }
        isWritingAudio = false
        isCapturingAudio = false
    }

    func recoverActiveRecordingIfNeeded() async {
        guard isRecording, !waitingForMediaServicesReset, !isPerformingRecovery else { return }
        let action = continuityPolicy.handle(
            .recoveryOpportunity(backendActive: hasActiveRecordingBackend)
        )
        guard action == .recover else { return }
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reactivar la grabacion: %@")
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
        try session.setCategory(
            RecordingAudioSessionPolicy.category,
            mode: RecordingAudioSessionPolicy.mode,
            options: RecordingAudioSessionPolicy.options
        )
        do {
            // This is a preference, not a guarantee. It prevents some banner-
            // style system alerts from interrupting an active recording, while
            // the recovery path below still handles unavoidable interruptions.
            try session.setPrefersNoInterruptionsFromSystemAlerts(true)
        } catch {
            recordDiagnostic(.systemAlertInterruptionPreferenceUnavailable, error: error)
        }
        try session.setActive(true)
    }

    private func startRecordingBackend() throws {
        guard let settings = currentSettings else { throw RecorderError.missingSettings }
        guard RecordingBackendPolicy.backend(for: settings.mode) == .continuousAudioEngine else {
            throw RecorderError.missingSettings
        }
        try startEngine()
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
        if !engine.isRunning {
            handleUnexpectedBackendFailure(
                RecorderError.backendStoppedUnexpectedly,
                diagnosticCode: .backendStoppedUnexpectedly
            )
        } else if segmentRotationRetryTask == nil,
                  let lastBackendActivityAt,
                  Date().timeIntervalSince(lastBackendActivityAt) > 5 {
            handleUnexpectedBackendFailure(
                RecorderError.audioInputStalled,
                diagnosticCode: .backendStoppedUnexpectedly
            )
        }
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
                    soundTailDuration: settings.soundTailDuration,
                    capturesAllAudio: settings.mode == .everything
                )
            )
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        captureDiagnosticInputFormat(inputFormat)
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
        cancelSegmentRotationRetry()
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
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        captureDiagnosticInputFormat(inputFormat)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.audioInputUnavailable
        }
        let preparedFile = try AVAudioFile(
            forWriting: url,
            settings: settings.quality.recordingSettings(matching: inputFormat)
        )

        // Commit only after the next destination is known to be writable. A
        // preparation failure must never discard or relabel the prior segment.
        completeCurrentSegment()
        currentSettings = settings
        currentFile = preparedFile
        currentURL = url
        currentSegmentCompletionToken = segmentCompletionGate.beginSegment()
        currentSegmentStartedAt = Date()
        writtenDuration = 0
        didWriteCurrentSegment = false
        elapsed = 0
        isWritingAudio = settings.mode == .everything
    }

    private func rotateSegment() {
        guard continuityPolicy.handle(.segmentLimitReached) == .rotateSegment else { return }
        recordDiagnostic(.rotationRequested)
        attemptSegmentRotation()
    }

    private func attemptSegmentRotation() {
        guard isRecording, engine.isRunning else {
            handleUnexpectedBackendFailure(
                RecorderError.backendStoppedUnexpectedly,
                diagnosticCode: .backendStoppedUnexpectedly
            )
            return
        }

        do {
            try startNewSegment()
            guard let currentFile, let settings = currentSettings else {
                throw RecorderError.missingSettings
            }
            soundProcessorGeneration = soundProcessor.start(
                file: currentFile,
                settings: SoundActivatedAudioSettings(
                    segmentDuration: settings.segmentDuration,
                    thresholdDB: settings.thresholdDB,
                    soundTailDuration: settings.soundTailDuration,
                    capturesAllAudio: settings.mode == .everything
                )
            )
            lastBackendActivityAt = Date()
            isCapturingAudio = hasActiveRecordingBackend
            _ = continuityPolicy.handle(.nextSegmentStarted)
            cancelSegmentRotationRetry()
            cancelRecoveryRetry()
            lastError = nil
            recordDiagnostic(.rotationSucceeded)
        } catch {
            _ = continuityPolicy.handle(.nextSegmentFailed)
            recordDiagnostic(.rotationDeferred, error: error)
            scheduleSegmentRotationRetry(
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
        if awaitingFirstRecoveredBuffer {
            awaitingFirstRecoveredBuffer = false
            recordDiagnostic(
                .recoveryFirstBufferObserved,
                detailCode: progress.didWrite ? 1 : 0
            )
        }
        lastBackendActivityAt = Date()
        applySoundProcessorState(progress)
        if let errorDescription = progress.errorDescription {
            let error = RecorderError.audioWriteFailed(errorDescription)
            recordDiagnostic(.audioWriteFailed, error: error)
            handleUnexpectedBackendFailure(error, diagnosticCode: .audioWriteFailed)
            return
        }
        if progress.reachedSegmentLimit, isRecording {
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
        guard let url = currentURL,
              let startedAt = currentSegmentStartedAt,
              let currentSettings,
              let completionToken = currentSegmentCompletionToken else {
            currentFile = nil
            currentURL = nil
            currentSegmentCompletionToken = nil
            segmentCompletionGate.clear()
            currentSegmentStartedAt = nil
            writtenDuration = 0
            didWriteCurrentSegment = false
            elapsed = 0
            return
        }

        guard segmentCompletionGate.claimCompletion(for: completionToken) else {
            currentFile = nil
            currentURL = nil
            currentSegmentCompletionToken = nil
            currentSegmentStartedAt = nil
            writtenDuration = 0
            didWriteCurrentSegment = false
            elapsed = 0
            return
        }

        currentFile = nil
        currentSegmentCompletionToken = nil
        let duration = writtenDuration
        guard didWriteCurrentSegment, duration > 0.02 else {
            deleteFileIfNeeded(url)
            currentURL = nil
            currentSegmentCompletionToken = nil
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
        currentSegmentCompletionToken = nil
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
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Never rebuild the graph synchronously inside AVAudioEngine's
            // configuration callback. Because this observer is delivered on the
            // main queue, the MainActor task cannot execute until this callback
            // returns. Ignore events from an already-replaced generation.
            Task { @MainActor in
                await self?.handleAudioEngineConfigurationChange(notification)
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
        guard !waitingForMediaServicesReset else { return }
        if isRecording {
            recordDiagnostic(.enteredForeground)
        }
        let action = continuityPolicy.handle(
            .enteredForeground(backendActive: hasActiveRecordingBackend)
        )
        if action == .recover {
            await recoverRecordingBackend(
                messageFormat: L("No se pudo reactivar la grabacion: %@")
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
        cancelSegmentRotationRetry()
        invalidateCurrentAudioEngine()
        abandonAudioObjectsPreservingSegment()
        _ = continuityPolicy.handle(.mediaServicesLost)
        recordDiagnostic(.mediaServicesLost)
    }

    private func recoverAfterMediaServicesReset() async {
        guard isRecording else { return }
        waitingForMediaServicesReset = false
        _ = continuityPolicy.handle(.mediaServicesReset)
        recordDiagnostic(.mediaServicesReset)
        await recoverRecordingBackend(
            messageFormat: L("No se pudo recuperar el audio del sistema: %@")
        )
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            pauseForAudioInterruption(
                rawType: Int(rawType),
                rawReason: (notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.intValue,
                wasSuspended: (notification.userInfo?[AVAudioSessionInterruptionWasSuspendedKey] as? NSNumber)?.boolValue
            )
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            Task {
                await resumeAfterAudioInterruption(
                    shouldResume: shouldResume,
                    rawOptions: Int(rawOptions),
                    rawReason: (notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.intValue,
                    wasSuspended: (notification.userInfo?[AVAudioSessionInterruptionWasSuspendedKey] as? NSNumber)?.boolValue
                )
            }
        @unknown default:
            break
        }
    }

    private func pauseForAudioInterruption(
        rawType: Int,
        rawReason: Int?,
        wasSuspended: Bool?
    ) {
        guard isRecording else { return }
        recordDiagnostic(
            .interruptionBegan,
            interruptionType: rawType,
            interruptionReason: rawReason,
            interruptionWasSuspended: wasSuspended
        )
        guard continuityPolicy.handle(.interruptionBegan) == .pauseAndFinalize else { return }
        isInterrupted = true
        isCapturingAudio = false
        setWritingAudio(false)
        cancelRecoveryRetry()
        cancelSegmentRotationRetry()
        invalidateCurrentAudioEngine()
        abandonAudioObjectsPreservingSegment()
        let pausedMessage = L("Grabacion pausada por otra app. Se reanudara sola.")
        lastError = pausedMessage
        // Apple doesn't guarantee a matching interruption-ended notification.
        // Keep a single, cancellable retry alive so a recording with explicit
        // user intent can recover even when Siri or suspension omits that edge.
        scheduleRecoveryRetry(message: pausedMessage)
    }

    private func resumeAfterAudioInterruption(
        shouldResume: Bool,
        rawOptions: Int,
        rawReason: Int?,
        wasSuspended: Bool?
    ) async {
        guard isRecording, settingsStore != nil else { return }
        if shouldResume {
            recordDiagnostic(
                .interruptionEndedResume,
                interruptionType: Int(AVAudioSession.InterruptionType.ended.rawValue),
                interruptionOptions: rawOptions,
                interruptionReason: rawReason,
                interruptionWasSuspended: wasSuspended
            )
        } else {
            recordDiagnostic(
                .interruptionEndedNoResume,
                interruptionType: Int(AVAudioSession.InterruptionType.ended.rawValue),
                interruptionOptions: rawOptions,
                interruptionReason: rawReason,
                interruptionWasSuspended: wasSuspended
            )
        }
        let action = continuityPolicy.handle(.interruptionEnded(shouldResume: shouldResume))
        guard action == .recover else { return }
        // `shouldResume` is a playback-oriented recommendation. This app has
        // an explicit, still-active recording intent, so it attempts recovery
        // after every interruption end and lets setActive/engine failures feed
        // the bounded retry path until the microphone is actually available.
        cancelRecoveryRetry()
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reanudar la grabacion: %@")
        )
    }

    private func handleAudioEngineConfigurationChange(_ notification: Notification) async {
        guard isRecording,
              let changedEngine = notification.object as? AVAudioEngine,
              RecordingEngineGenerationGate.accepts(
                changedEngine: changedEngine,
                currentEngine: engine
              ) else {
            return
        }

        recordDiagnostic(
            .audioEngineConfigurationChanged,
            detailCode: currentAudioEngineGeneration
        )
        invalidateCurrentAudioEngine()
        guard !waitingForMediaServicesReset else { return }
        if isInterrupted {
            scheduleRecoveryRetry(message: L("Grabacion pausada por otra app. Se reanudara sola."))
            return
        }
        if isPerformingRecovery {
            scheduleRecoveryRetry(message: L("No se pudo reactivar la grabacion."))
            return
        }

        _ = continuityPolicy.handle(.backendFailed)
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reactivar la grabacion: %@")
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
        invalidateCurrentAudioEngine()
        await recoverRecordingBackend(
            messageFormat: L("No se pudo reactivar la grabacion: %@")
        )
    }

    private func handleUnexpectedBackendFailure(
        _ error: Error,
        diagnosticCode: RecordingDiagnosticCode
    ) {
        guard isRecording, !isInterrupted, !isPerformingRecovery else { return }
        _ = continuityPolicy.handle(.backendFailed)
        recordDiagnostic(diagnosticCode, error: error)
        cancelSegmentRotationRetry()
        stopEngine()
        completeCurrentSegment()
        invalidateCurrentAudioEngine()
        scheduleRecoveryRetry(
            message: String(format: L("No se pudo reanudar la grabacion: %@"), error.localizedDescription),
            error: error
        )
    }

    private func recoverRecordingBackend(messageFormat: String) async {
        guard isRecording, !isPerformingRecovery else { return }
        isPerformingRecovery = true
        awaitingFirstRecoveredBuffer = false
        recordDiagnostic(.recoveryAttemptStarted)
        cancelSegmentRotationRetry()
        defer { isPerformingRecovery = false }

        if recoveryMustAbandonEngine {
            abandonAudioObjectsPreservingSegment()
        } else {
            stopEngine()
            completeCurrentSegment()
        }
        recoveryMustAbandonEngine = false

        var driver = recoveryDriver
        let invalidationTicket = recoveryInvalidationGate.ticket()
        do {
            let generation = try driver.attempt(using: RecordingRecoveryHardwareSteps(
                activateSession: { [unowned self] in
                    self.recordDiagnostic(
                        .audioSessionActivationAttempted,
                        recoveryStage: .activateSession
                    )
                    do {
                        try self.configureAudioSession()
                        self.recordDiagnostic(
                            .audioSessionActivationSucceeded,
                            recoveryStage: .activateSession
                        )
                    } catch {
                        self.recordDiagnostic(
                            .audioSessionActivationFailed,
                            recoveryStage: .activateSession,
                            error: error
                        )
                        throw error
                    }
                },
                rebuildAudioEngine: { [unowned self] generation in
                    self.replaceAudioEngine(generation: generation)
                },
                validateInputAndOpenSegment: { [unowned self] in
                    try self.startNewSegment()
                    self.recordDiagnostic(
                        .recoverySegmentOpened,
                        recoveryStage: .validateInputAndOpenSegment
                    )
                },
                installTapAndStartEngine: { [unowned self] in
                    self.awaitingFirstRecoveredBuffer = true
                    self.recordDiagnostic(
                        .recoveryEngineStartAttempted,
                        recoveryStage: .installTapAndStartEngine
                    )
                    do {
                        try self.startRecordingBackend()
                        self.recordDiagnostic(
                            .recoveryEngineStarted,
                            recoveryStage: .installTapAndStartEngine
                        )
                    } catch {
                        self.awaitingFirstRecoveredBuffer = false
                        throw error
                    }
                }
            ))
            recoveryDriver = driver
            guard recoveryInvalidationGate.accepts(ticket: invalidationTicket) else {
                throw RecordingRecoveryInvalidatedError()
            }
            isInterrupted = false
            isCapturingAudio = true
            cancelRecoveryRetry()
            lastError = nil
            _ = continuityPolicy.handle(.recoverySucceeded)
            recordDiagnostic(.recoverySucceeded, detailCode: generation)
        } catch {
            recoveryDriver = driver
            awaitingFirstRecoveredBuffer = false
            isCapturingAudio = false
            invalidateCurrentAudioEngine()
            _ = continuityPolicy.handle(.recoveryFailed)
            let attemptError = error as? RecordingRecoveryAttemptError
            let reportedError: Error = error is RecordingRecoveryInvalidatedError
                ? RecorderError.backendStoppedUnexpectedly
                : (attemptError?.underlyingError ?? error)
            recordDiagnostic(
                .recoveryFailed,
                detailCode: attemptError?.generation,
                recoveryStage: attemptError?.stage,
                error: reportedError
            )
            scheduleRecoveryRetry(
                message: String(format: messageFormat, reportedError.localizedDescription),
                error: reportedError
            )
        }
    }

    private func abandonAudioObjectsPreservingSegment() {
        recorderTimer?.invalidate()
        recorderTimer = nil
        cancelSegmentRotationRetry()

        // Every caller reaches this method after the AVFoundation notification
        // callback has returned. Tear down and release the retired graph here,
        // never inside AVAudioEngineConfigurationChange's internal queue.
        let retiredEngine = engine
        if audioTapInstalled {
            retiredEngine.inputNode.removeTap(onBus: 0)
        }
        retiredEngine.stop()
        audioTapInstalled = false
        engine = AVAudioEngine()
        lastObservedInputSampleRate = 0
        lastObservedInputChannelCount = 0

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

    private func replaceAudioEngine(generation: Int) {
        // The placeholder or prior generation is never reused. It has no active
        // tap after `abandonAudioObjectsPreservingSegment`, but stopping before
        // release keeps this path safe if recovery was entered directly.
        engine.stop()
        engine = AVAudioEngine()
        currentAudioEngineGeneration = generation
        lastObservedInputSampleRate = 0
        lastObservedInputChannelCount = 0
        audioTapInstalled = false
        lastBackendActivityAt = nil
        recordDiagnostic(
            .audioEngineRebuilt,
            detailCode: generation,
            recoveryStage: .rebuildAudioEngine
        )
    }

    private func invalidateCurrentAudioEngine() {
        recoveryMustAbandonEngine = true
        recoveryInvalidationGate.invalidate()
    }

    private func scheduleRecoveryRetry(message: String, error: Error? = nil) {
        guard isRecording else { return }
        persistRecordingIntent(true)
        setWritingAudio(false)
        isCapturingAudio = false
        lastError = message
        recordDiagnostic(.recoveryScheduled, error: error)

        guard recoveryRetryTask == nil else {
            recordDiagnostic(.recoveryRetryDeduplicated)
            return
        }
        let token = UUID()
        recoveryRetryToken = token
        recoveryRetryTask = Task { [weak self] in
            guard await RecordingRetryGate.wait(nanoseconds: 5_000_000_000) else { return }
            await self?.runScheduledRecoveryRetry(token: token)
        }
    }

    private func runScheduledRecoveryRetry(token: UUID) async {
        guard recoveryRetryToken == token else { return }
        recoveryRetryTask = nil
        recoveryRetryToken = nil
        recordDiagnostic(.recoveryRetryFired)
        guard isRecording else { return }
        await recoverActiveRecordingIfNeeded()

        if isRecording, !hasActiveRecordingBackend {
            scheduleRecoveryRetry(message: lastError ?? L("No se pudo reanudar la grabacion."))
        }
    }

    private func cancelRecoveryRetry() {
        let didCancel = recoveryRetryTask != nil || recoveryRetryToken != nil
        recoveryRetryTask?.cancel()
        recoveryRetryTask = nil
        recoveryRetryToken = nil
        if didCancel {
            recordDiagnostic(.recoveryRetryCancelled)
        }
    }

    private func scheduleSegmentRotationRetry(message: String, error: Error?) {
        guard isRecording else { return }
        persistRecordingIntent(true)
        setWritingAudio(false)
        isCapturingAudio = engine.isRunning
        lastError = message
        recordDiagnostic(.recoveryScheduled, error: error)

        guard segmentRotationRetryTask == nil else { return }
        segmentRotationRetryTask = Task { [weak self] in
            guard await RecordingRetryGate.wait(nanoseconds: 500_000_000) else { return }
            await self?.runSegmentRotationRetry()
        }
    }

    private func runSegmentRotationRetry() {
        segmentRotationRetryTask = nil
        guard isRecording else { return }
        attemptSegmentRotation()
    }

    private func cancelSegmentRotationRetry() {
        segmentRotationRetryTask?.cancel()
        segmentRotationRetryTask = nil
    }

    private var hasActiveRecordingBackend: Bool {
        engine.isRunning && soundProcessorGeneration != nil
    }

    private func recordDiagnostic(
        _ code: RecordingDiagnosticCode,
        detailCode: Int? = nil,
        interruptionType: Int? = nil,
        interruptionOptions: Int? = nil,
        interruptionReason: Int? = nil,
        interruptionWasSuspended: Bool? = nil,
        recoveryStage: RecordingRecoveryStage? = nil,
        error: Error? = nil
    ) {
        diagnostics.record(
            code,
            sessionID: diagnosticSessionID,
            phase: continuityPolicy.phase,
            mode: currentSettings?.mode,
            detailCode: detailCode,
            interruptionType: interruptionType,
            interruptionOptions: interruptionOptions,
            interruptionReason: interruptionReason,
            interruptionWasSuspended: interruptionWasSuspended,
            recoveryStage: recoveryStage,
            error: error,
            runtime: diagnosticRuntimeState
        )
    }

    private var diagnosticRuntimeState: RecordingDiagnosticRuntimeState {
        return RecordingDiagnosticRuntimeState(
            recordingIntent: continuityPolicy.hasRecordingIntent,
            engineRunning: engine.isRunning,
            inputSampleRate: lastObservedInputSampleRate,
            inputChannelCount: lastObservedInputChannelCount,
            interrupted: isInterrupted,
            recovering: isPerformingRecovery,
            retryScheduled: recoveryRetryTask != nil || recoveryRetryToken != nil
        )
    }

    private func captureDiagnosticInputFormat(_ format: AVAudioFormat) {
        lastObservedInputSampleRate = format.sampleRate
        lastObservedInputChannelCount = Int(format.channelCount)
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        recordDiagnostic(.backendStoppedUnexpectedly)
        isInterrupted = false
        cancelRecoveryRetry()
        cancelSegmentRotationRetry()
        if recoveryMustAbandonEngine {
            abandonAudioObjectsPreservingSegment()
        } else {
            stopEngine()
            completeCurrentSegment()
        }
        recoveryMustAbandonEngine = false
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
    case backendStoppedUnexpectedly
    case audioInputUnavailable
    case audioInputStalled
    case audioWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            L("No hay permiso para usar el microfono.")
        case .missingSettings:
            L("Faltan ajustes de grabacion.")
        case .backendStoppedUnexpectedly:
            L("La grabacion de audio se detuvo inesperadamente.")
        case .audioInputUnavailable:
            L("La entrada de audio no esta disponible.")
        case .audioInputStalled:
            L("La entrada de audio dejo de responder.")
        case let .audioWriteFailed(description):
            description
        }
    }
}
