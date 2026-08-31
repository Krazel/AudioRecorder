import AVFoundation

/// The recorder must remain eligible to reactivate while its scene is in the
/// background. A nonmixable `playAndRecord` session fails there with
/// `AVAudioSession.ErrorCode.cannotInterruptOthers` (`!int`).
enum RecordingAudioSessionPolicy {
    static let category: AVAudioSession.Category = .playAndRecord
    static let mode: AVAudioSession.Mode = .default
    static let options: AVAudioSession.CategoryOptions = [
        .allowBluetoothHFP,
        .defaultToSpeaker,
        .mixWithOthers
    ]
}
