import AVFoundation
import Foundation

struct SoundActivatedAudioSettings: Sendable {
    let segmentDuration: TimeInterval
    let thresholdDB: Float
    let soundTailDuration: TimeInterval
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

/// Owns analysis and file writes for sound-activated recording. Its state is
/// confined to `queue`; only coalesced progress snapshots cross to the UI.
final class SoundActivatedAudioProcessor: @unchecked Sendable {
    typealias ProgressHandler = @Sendable (SoundActivatedAudioProgress) -> Void

    private let queue = DispatchQueue(label: "com.dmkr.audio.sound-processing", qos: .userInitiated)
    private let analyzer = VoiceNoiseAnalyzer()
    private let progressHandler: ProgressHandler

    private var file: AVAudioFile?
    private var settings: SoundActivatedAudioSettings?
    private var generation: UUID?
    private var writtenDuration: TimeInterval = 0
    private var didWrite = false
    private var isWriting = false
    private var lastSoundAboveThresholdAt: Date?
    private var lastProgressUpdateAt = Date.distantPast
    private var isPaused = true

    init(progressHandler: @escaping ProgressHandler) {
        self.progressHandler = progressHandler
    }

    func start(file: AVAudioFile, settings: SoundActivatedAudioSettings) -> UUID {
        queue.sync {
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
            return newGeneration
        }
    }

    func enqueue(_ buffer: AVAudioPCMBuffer) {
        // AVAudioEngine can reuse its tap buffer after the callback returns.
        // Copy it before handing it to the serial processing queue.
        guard let copiedBuffer = buffer.deepCopy().map(CopiedAudioBuffer.init) else { return }
        queue.async { [weak self] in
            self?.process(copiedBuffer.value)
        }
    }

    func stop() -> SoundActivatedAudioProgress {
        queue.sync {
            isPaused = true
            let finalProgress = snapshot(level: nil, reachedSegmentLimit: false, errorDescription: nil)
            file = nil
            settings = nil
            generation = nil
            return finalProgress
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
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
        }
        progressHandler(snapshot(level: analysis.rms, reachedSegmentLimit: reachedSegmentLimit, errorDescription: nil))
    }

    private func shouldWrite(level: Float, settings: SoundActivatedAudioSettings, now: Date) -> Bool {
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
