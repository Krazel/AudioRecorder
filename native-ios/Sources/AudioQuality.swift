import AVFoundation
import Foundation

enum AudioQuality: String, CaseIterable, Codable, Identifiable {
    case veryLow
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veryLow: "Muy baja"
        case .low: "Baja"
        case .medium: "Media"
        case .high: "Alta (maxima)"
        }
    }

    var sampleRate: Double {
        switch self {
        case .veryLow: 8_000
        case .low: 16_000
        case .medium: 44_100
        case .high: 48_000
        }
    }

    var channelCount: AVAudioChannelCount {
        switch self {
        case .veryLow, .low: 1
        case .medium: 1
        case .high: 2
        }
    }

    var bitRate: Int {
        switch self {
        case .veryLow: 16_000
        case .low: 32_000
        case .medium: 96_000
        case .high: 192_000
        }
    }

    var fileExtension: String {
        switch self {
        case .veryLow, .low, .medium: "m4a"
        case .high: "caf"
        }
    }

    var commonFormat: AVAudioCommonFormat {
        switch self {
        case .veryLow, .low, .medium: .pcmFormatInt16
        case .high: .pcmFormatFloat32
        }
    }

    func recordingSettings(matching inputFormat: AVAudioFormat) -> [String: Any] {
        let sampleRate = inputFormat.sampleRate
        let channels = Int(inputFormat.channelCount)

        switch self {
        case .veryLow, .low, .medium:
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: bitRate,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            return settings
        case .high:
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false
            ]
            return settings
        }
    }

    var recorderSettings: [String: Any] {
        switch self {
        case .veryLow, .low, .medium:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: Int(channelCount),
                AVEncoderBitRateKey: bitRate,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
        case .high:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: Int(channelCount),
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false
            ]
        }
    }
}
