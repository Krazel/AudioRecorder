import AVFoundation
import Foundation

struct VoiceNoiseAnalysis {
    let rms: Float
    let likelyVoice: Bool
    let likelyNoise: Bool
}

final class VoiceNoiseAnalyzer {
    private let voiceThreshold: Float = -38
    private let noiseThreshold: Float = -54

    func analyze(_ buffer: AVAudioPCMBuffer) -> VoiceNoiseAnalysis {
        guard let channel = buffer.floatChannelData?.pointee else {
            return VoiceNoiseAnalysis(rms: -120, likelyVoice: false, likelyNoise: true)
        }

        let count = Int(buffer.frameLength)
        guard count > 0 else {
            return VoiceNoiseAnalysis(rms: -120, likelyVoice: false, likelyNoise: true)
        }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }

        let mean = sum / Float(count)
        let rms = 20 * log10(max(sqrt(mean), 0.000_001))
        return VoiceNoiseAnalysis(
            rms: rms,
            likelyVoice: rms > voiceThreshold,
            likelyNoise: rms > noiseThreshold && rms <= voiceThreshold
        )
    }
}
