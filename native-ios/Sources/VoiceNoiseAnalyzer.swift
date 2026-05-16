import AVFoundation
import Foundation

struct VoiceNoiseAnalysis {
    let rms: Float
}

final class VoiceNoiseAnalyzer {
    func analyze(_ buffer: AVAudioPCMBuffer) -> VoiceNoiseAnalysis {
        let count = Int(buffer.frameLength)
        guard count > 0 else {
            return VoiceNoiseAnalysis(rms: -120)
        }

        if let channelData = buffer.floatChannelData {
            var sum: Float = 0
            let channels = Int(buffer.format.channelCount)
            for channelIndex in 0..<max(channels, 1) {
                let channel = channelData[channelIndex]
                for frameIndex in 0..<count {
                    let sample = channel[frameIndex]
                    sum += sample * sample
                }
            }
            let mean = sum / Float(count * max(channels, 1))
            return VoiceNoiseAnalysis(rms: rms(fromMeanSquare: mean))
        }

        if let channelData = buffer.int16ChannelData {
            var sum: Float = 0
            let channels = Int(buffer.format.channelCount)
            for channelIndex in 0..<max(channels, 1) {
                let channel = channelData[channelIndex]
                for frameIndex in 0..<count {
                    let sample = Float(channel[frameIndex]) / Float(Int16.max)
                    sum += sample * sample
                }
            }
            let mean = sum / Float(count * max(channels, 1))
            return VoiceNoiseAnalysis(rms: rms(fromMeanSquare: mean))
        }

        return VoiceNoiseAnalysis(rms: -120)
    }

    private func rms(fromMeanSquare mean: Float) -> Float {
        20 * log10(max(sqrt(mean), 0.000_001))
    }
}
