import AVFoundation
import Foundation

struct VoiceNoiseAnalysis {
    let rms: Float
}

final class VoiceNoiseAnalyzer {
    func analyze(_ buffer: AVAudioPCMBuffer) -> VoiceNoiseAnalysis {
        guard let channel = buffer.floatChannelData?.pointee else {
            return VoiceNoiseAnalysis(rms: -120)
        }

        let count = Int(buffer.frameLength)
        guard count > 0 else {
            return VoiceNoiseAnalysis(rms: -120)
        }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }

        let mean = sum / Float(count)
        let rms = 20 * log10(max(sqrt(mean), 0.000_001))
        return VoiceNoiseAnalysis(rms: rms)
    }
}
