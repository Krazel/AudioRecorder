import AVFoundation
import Foundation

struct SoundActivatedAudioSettings: Sendable {
    let segmentDuration: TimeInterval
    let thresholdDB: Float
    let soundTailDuration: TimeInterval
    let capturesAllAudio: Bool
}

struct SoundActivatedAudioProgress: Sendable {
    let generation: UUID?
    let level: Float?
    let writtenDuration: TimeInterval
    let didWrite: Bool
    let isWriting: Bool
    let reachedSegmentLimit: Bool
    let errorDescription: String?
}

/// Owns analysis and file writes for both recording modes. The audio engine
/// remains alive while output files rotate; buffers received during that
/// handoff are retained in a bounded FIFO. State is confined to `queue`.
final class SoundActivatedAudioProcessor: @unchecked Sendable {
    typealias ProgressHandler = @Sendable (SoundActivatedAudioProgress) -> Void
    typealias ActivityHandler = @Sendable (UUID?) -> Void

    private let queue = DispatchQueue(label: "com.dmkr.audio.sound-processing", qos: .userInitiated)
    private let pendingBufferLock = NSLock()
    private let maximumPendingBuffers = 64
    private let analyzer = VoiceNoiseAnalyzer()
    private let progressHandler: ProgressHandler
    private let activityHandler: ActivityHandler

    private var file: AVAudioFile?
    private var settings: SoundActivatedAudioSettings?
    private var generation: UUID?
    private var writtenDuration: TimeInterval = 0
    private var didWrite = false
    private var isWriting = false
    private var lastSoundAboveThresholdAt: Date?
    private var lastProgressUpdateAt = Date.distantPast
    private var isPaused = true
    private var isAwaitingSegmentRotation = false
    private var rotationBacklog = SegmentRotationBacklog<AVAudioPCMBuffer>(capacity: 128)
    private var pendingBufferCount = 0
    private var didSignalBufferOverflow = false

    init(
        progressHandler: @escaping ProgressHandler,
        activityHandler: @escaping ActivityHandler = { _ in }
    ) {
        self.progressHandler = progressHandler
        self.activityHandler = activityHandler
    }

    func start(file: AVAudioFile, settings: SoundActivatedAudioSettings) -> UUID {
        queue.sync {
            let bufferedDuringRotation = rotationBacklog.drain()
            let newGeneration = UUID()
            self.file = file
            self.settings = settings
            generation = newGeneration
            writtenDuration = 0
            didWrite = false
            isWriting = false
            lastSoundAboveThresholdAt = nil
            lastProgressUpdateAt = .distantPast
            isPaused = false
            isAwaitingSegmentRotation = false
            pendingBufferLock.lock()
            didSignalBufferOverflow = false
            pendingBufferLock.unlock()
            for buffer in bufferedDuringRotation {
                process(buffer)
            }
            return newGeneration
        }
    }

    func enqueue(_ buffer: AVAudioPCMBuffer) {
        guard reservePendingBufferSlot() else {
            signalPendingBufferFailureIfNeeded()
            return
        }

        // AVAudioEngine can reuse its tap buffer after the callback returns.
        // Copy it before handing it to the serial processing queue.
        guard let copiedBuffer = buffer.deepCopy().map(CopiedAudioBuffer.init) else {
            releasePendingBufferSlot()
            signalPendingBufferFailureIfNeeded()
            return
        }
        queue.async { [weak self] in
            autoreleasepool {
                defer { self?.releasePendingBufferSlot() }
                self?.process(copiedBuffer.value)
            }
        }
    }

    private func reservePendingBufferSlot() -> Bool {
        pendingBufferLock.lock()
        defer { pendingBufferLock.unlock() }
        guard pendingBufferCount < maximumPendingBuffers else { return false }
        pendingBufferCount += 1
        return true
    }

    private func releasePendingBufferSlot() {
        pendingBufferLock.lock()
        pendingBufferCount = max(0, pendingBufferCount - 1)
        pendingBufferLock.unlock()
    }

    private func signalPendingBufferFailureIfNeeded() {
        pendingBufferLock.lock()
        let shouldSignal = !didSignalBufferOverflow
        didSignalBufferOverflow = true
        pendingBufferLock.unlock()
        guard shouldSignal else { return }

        queue.async { [weak self] in
            guard let self, !isPaused || isAwaitingSegmentRotation else { return }
            isPaused = true
            isAwaitingSegmentRotation = false
            isWriting = false
            progressHandler(
                snapshot(
                    level: nil,
                    reachedSegmentLimit: false,
                    errorDescription: L("La entrada de audio dejo de responder.")
                )
            )
        }
    }

    func stop() -> SoundActivatedAudioProgress {
        queue.sync {
            isPaused = true
            isAwaitingSegmentRotation = false
            rotationBacklog.removeAll()
            let finalProgress = snapshot(level: nil, reachedSegmentLimit: false, errorDescription: nil)
            file = nil
            settings = nil
            generation = nil
            return finalProgress
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        activityHandler(generation)
        if isAwaitingSegmentRotation {
            guard rotationBacklog.append(buffer) else {
                isAwaitingSegmentRotation = false
                isPaused = true
                isWriting = false
                progressHandler(
                    snapshot(
                        level: nil,
                        reachedSegmentLimit: false,
                        errorDescription: L("La entrada de audio dejo de responder.")
                    )
                )
                return
            }
            return
        }

        guard !isPaused, let file, let settings else { return }

        let analysis = analyzer.analyze(buffer)
        let now = Date()
        isWriting = shouldWrite(level: analysis.rms, settings: settings, now: now)

        if isWriting {
            do {
                try file.write(from: buffer)
                writtenDuration += Double(buffer.frameLength) / buffer.format.sampleRate
                didWrite = true
            } catch {
                isPaused = true
                isWriting = false
                progressHandler(snapshot(level: analysis.rms, reachedSegmentLimit: false, errorDescription: error.localizedDescription))
                return
            }
        }

        let reachedSegmentLimit = writtenDuration >= settings.segmentDuration
        let shouldPublish = now.timeIntervalSince(lastProgressUpdateAt) >= 0.25 || reachedSegmentLimit
        guard shouldPublish else { return }

        lastProgressUpdateAt = now
        if reachedSegmentLimit {
            isPaused = true
            isAwaitingSegmentRotation = true
        }
        progressHandler(snapshot(level: analysis.rms, reachedSegmentLimit: reachedSegmentLimit, errorDescription: nil))
    }

    private func shouldWrite(level: Float, settings: SoundActivatedAudioSettings, now: Date) -> Bool {
        if settings.capturesAllAudio {
            return true
        }

        if level >= settings.thresholdDB {
            lastSoundAboveThresholdAt = now
            return true
        }

        guard settings.soundTailDuration > 0, let lastSoundAboveThresholdAt else {
            return false
        }
        return now.timeIntervalSince(lastSoundAboveThresholdAt) <= settings.soundTailDuration
    }

    private func snapshot(
        level: Float?,
        reachedSegmentLimit: Bool,
        errorDescription: String?
    ) -> SoundActivatedAudioProgress {
        SoundActivatedAudioProgress(
            generation: generation,
            level: level,
            writtenDuration: writtenDuration,
            didWrite: didWrite,
            isWriting: isWriting,
            reachedSegmentLimit: reachedSegmentLimit,
            errorDescription: errorDescription
        )
    }
}

struct SegmentRotationBacklog<Element> {
    let capacity: Int
    private(set) var values: [Element] = []

    init(capacity: Int) {
        self.capacity = max(0, capacity)
    }

    mutating func append(_ value: Element) -> Bool {
        guard values.count < capacity else { return false }
        values.append(value)
        return true
    }

    mutating func drain() -> [Element] {
        defer { values.removeAll(keepingCapacity: true) }
        return values
    }

    mutating func removeAll() {
        values.removeAll(keepingCapacity: true)
    }
}

private final class CopiedAudioBuffer: @unchecked Sendable {
    let value: AVAudioPCMBuffer

    init(_ value: AVAudioPCMBuffer) {
        self.value = value
    }
}

private extension AVAudioPCMBuffer {
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        copy.frameLength = frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }

        for index in sourceBuffers.indices {
            let byteCount = Int(sourceBuffers[index].mDataByteSize)
            guard let source = sourceBuffers[index].mData,
                  let destination = destinationBuffers[index].mData,
                  byteCount <= Int(destinationBuffers[index].mDataByteSize) else {
                return nil
            }
            memcpy(destination, source, byteCount)
        }
        return copy
    }
}
