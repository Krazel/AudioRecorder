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
    private var pipeline: AudioRecordingPipeline?
    private var installedObservers = false
    private var settings: RecordingSettingsStore?
    private var library: RecordingLibrary?
    private var uploadQueue: CloudUploadQueue?
    private var shouldResumeAfterInterruption = false

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
            let pipeline = try makePipeline(settings: settings)
            self.pipeline = pipeline
            try startEngine(pipeline: pipeline)
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
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        finishPipeline()
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
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }

    private func startEngine(pipeline: AudioRecordingPipeline) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { buffer, _ in
            guard let copy = buffer.deepCopy() else {
                return
            }
            pipeline.process(copy)
        }

        engine.prepare()
        try engine.start()
    }

    private func makePipeline(settings: RecordingSettingsStore) throws -> AudioRecordingPipeline {
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        currentSegmentStartedAt = Date()
        elapsed = 0
        currentLevel = -120
        isWritingAudio = false
        return try AudioRecordingPipeline(
            settings: RecordingPipelineSettings(settings),
            inputFormat: inputFormat,
            onMetrics: { [weak self] metrics in
                Task { @MainActor in
                    self?.apply(metrics)
                }
            },
            onSegment: { [weak self] item in
                Task { @MainActor in
                    self?.addCompletedSegment(item)
                }
            },
            onSegmentStarted: { [weak self] date in
                Task { @MainActor in
                    self?.currentSegmentStartedAt = date
                    self?.elapsed = 0
                }
            },
            onError: { [weak self] message in
                Task { @MainActor in
                    self?.lastError = message
                    self?.stop()
                }
            }
        )
    }

    private func apply(_ metrics: RecordingMetrics) {
        currentLevel = metrics.level
        elapsed = metrics.elapsed
        if isWritingAudio != metrics.isWriting {
            isWritingAudio = metrics.isWriting
        }
    }

    private func addCompletedSegment(_ item: RecordingItem) {
        library?.addImmediately(item)
        if settings?.uploadAutomatically == true {
            Task {
                await uploadQueue?.enqueue(
                    recording: item,
                    provider: settings?.cloudProvider ?? .none,
                    endpointURL: settings?.cloudProvider == .customServer ? settings?.customUploadEndpointURL : nil,
                    authToken: settings?.customUploadToken ?? ""
                )
                await uploadQueue?.processNext(library: library)
            }
        }
    }

    private func finishPipeline() {
        let pipeline = pipeline
        self.pipeline = nil
        pipeline?.stop()
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
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        finishPipeline()
        lastError = "Grabacion pausada por otra app. Se reanudara sola."
    }

    private func resumeAfterAudioInterruption() async {
        guard shouldResumeAfterInterruption, let settings else { return }
        shouldResumeAfterInterruption = false

        do {
            try configureAudioSession()
            let pipeline = try makePipeline(settings: settings)
            self.pipeline = pipeline
            try startEngine(pipeline: pipeline)
            isRecording = true
            isInterrupted = false
            lastError = nil
        } catch {
            isInterrupted = false
            isRecording = false
            isWritingAudio = false
            lastError = "No se pudo reanudar la grabacion: \(error.localizedDescription)"
            self.settings = settings
        }
    }

    private func emergencyStopAndSave() {
        guard isRecording else { return }
        shouldResumeAfterInterruption = false
        isInterrupted = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        finishPipeline()
        isRecording = false
        isWritingAudio = false
    }
}

private struct RecordingPipelineSettings {
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

private struct RecordingMetrics {
    let level: Float
    let elapsed: TimeInterval
    let isWriting: Bool
}

private final class AudioRecordingPipeline {
    private let queue = DispatchQueue(label: "com.dmkr.audio.recording.pipeline", qos: .userInitiated)
    private let analyzer = VoiceNoiseAnalyzer()
    private let settings: RecordingPipelineSettings
    private let inputFormat: AVAudioFormat
    private let onMetrics: (RecordingMetrics) -> Void
    private let onSegment: (RecordingItem) -> Void
    private let onSegmentStarted: (Date) -> Void
    private let onError: (String) -> Void

    private var currentFile: AVAudioFile?
    private var currentURL: URL?
    private var currentSegmentStartedAt: Date?
    private var writtenDuration: TimeInterval = 0
    private var didWriteCurrentSegment = false
    private var lastLevel: Float = -120
    private var lastMetricsPublishAt: TimeInterval = 0
    private var isWriting = false
    private var stopped = false

    init(
        settings: RecordingPipelineSettings,
        inputFormat: AVAudioFormat,
        onMetrics: @escaping (RecordingMetrics) -> Void,
        onSegment: @escaping (RecordingItem) -> Void,
        onSegmentStarted: @escaping (Date) -> Void,
        onError: @escaping (String) -> Void
    ) throws {
        self.settings = settings
        self.inputFormat = inputFormat
        self.onMetrics = onMetrics
        self.onSegment = onSegment
        self.onSegmentStarted = onSegmentStarted
        self.onError = onError
        try startNewSegment()
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            self?.processOnQueue(buffer)
        }
    }

    func stop() {
        queue.sync {
            stopped = true
            completeCurrentSegment()
        }
    }

    private func processOnQueue(_ buffer: AVAudioPCMBuffer) {
        guard !stopped else { return }
        let analysis = analyzer.analyze(buffer)
        lastLevel = analysis.rms

        guard shouldWriteBuffer(analysis: analysis) else {
            publishMetricsIfNeeded(force: isWriting, isWriting: false)
            isWriting = false
            return
        }

        do {
            try currentFile?.write(from: buffer)
            let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
            writtenDuration += bufferDuration
            didWriteCurrentSegment = true
            isWriting = true
            publishMetricsIfNeeded(isWriting: true)

            if writtenDuration >= settings.segmentDuration {
                try rotateSegment()
            }
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func startNewSegment() throws {
        let url = try RecordingStorage.nextSegmentURL(mode: settings.mode, quality: settings.quality)
        currentFile = try AVAudioFile(forWriting: url, settings: settings.quality.recordingSettings(matching: inputFormat))
        currentURL = url
        let startedAt = Date()
        currentSegmentStartedAt = startedAt
        writtenDuration = 0
        didWriteCurrentSegment = false
        lastMetricsPublishAt = 0
        isWriting = false
        onSegmentStarted(startedAt)
    }

    private func rotateSegment() throws {
        completeCurrentSegment()
        try startNewSegment()
    }

    private func completeCurrentSegment() {
        guard let url = currentURL, let startedAt = currentSegmentStartedAt else {
            currentFile = nil
            currentURL = nil
            return
        }

        currentFile = nil
        let duration = writtenDuration
        guard didWriteCurrentSegment, duration > 0.02 else {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            currentURL = nil
            writtenDuration = 0
            didWriteCurrentSegment = false
            return
        }

        onSegment(RecordingItem(
            id: UUID(),
            createdAt: startedAt,
            duration: duration,
            fileURL: url,
            mode: settings.mode,
            quality: settings.quality,
            uploadState: settings.uploadState,
            customName: nil
        ))

        currentURL = nil
        writtenDuration = 0
        didWriteCurrentSegment = false
    }

    private func shouldWriteBuffer(analysis: VoiceNoiseAnalysis) -> Bool {
        switch settings.mode {
        case .everything:
            return true
        case .soundActivated:
            return analysis.rms >= settings.thresholdDB
        }
    }

    private func publishMetricsIfNeeded(force: Bool = false, isWriting: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        guard force || now - lastMetricsPublishAt >= 0.25 else { return }
        lastMetricsPublishAt = now
        onMetrics(RecordingMetrics(level: lastLevel, elapsed: writtenDuration, isWriting: isWriting))
    }
}

private extension AVAudioPCMBuffer {
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        copy.frameLength = frameLength

        let sourceBuffers = UnsafeAudioBufferListPointer(audioBufferList)
        let targetBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<sourceBuffers.count {
            guard let sourceData = sourceBuffers[index].mData,
                  let targetData = targetBuffers[index].mData else {
                continue
            }
            memcpy(targetData, sourceData, Int(sourceBuffers[index].mDataByteSize))
        }
        return copy
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
