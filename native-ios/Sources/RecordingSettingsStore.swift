import Foundation

@MainActor
final class RecordingSettingsStore: ObservableObject {
    @Published var quality: AudioQuality {
        didSet { save() }
    }

    @Published var mode: RecordingMode {
        didSet { save() }
    }

    @Published var segmentMinutes: Int {
        didSet { save() }
    }

    @Published var recordingThresholdDB: Float {
        didSet { save() }
    }

    @Published var soundTailSeconds: Double {
        didSet { save() }
    }

    @Published var startRecordingOnLaunch: Bool {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    init() {
        let storedSegmentMinutes = defaults.object(forKey: "segmentMinutes") as? Int
        let storedThreshold = defaults.object(forKey: "recordingThresholdDB") as? Float
        let storedSoundTailSeconds = defaults.object(forKey: "soundTailSeconds") as? Double
        quality = AudioQuality(rawValue: defaults.string(forKey: "quality") ?? "") ?? .medium
        mode = RecordingMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .everything
        segmentMinutes = storedSegmentMinutes == 0 ? 15 : (storedSegmentMinutes ?? 15)
        recordingThresholdDB = storedThreshold ?? -45
        soundTailSeconds = storedSoundTailSeconds ?? 1.0
        startRecordingOnLaunch = defaults.object(forKey: "startRecordingOnLaunch") as? Bool ?? false
        defaults.removeObject(forKey: "cloudProvider")
        defaults.removeObject(forKey: "uploadAutomatically")
        defaults.removeObject(forKey: "customUploadEndpoint")
        defaults.removeObject(forKey: "customUploadToken")
    }

    var segmentDuration: TimeInterval {
        guard segmentMinutes > 0 else { return TimeInterval(15 * 60) }
        return TimeInterval(segmentMinutes * 60)
    }

    var sensitivityPercent: Int {
        let bounded = min(max(recordingThresholdDB, -80), -10)
        return Int(round(((-10 - bounded) / 70) * 100))
    }

    func setSensitivityPercent(_ percent: Double) {
        let bounded = min(max(percent, 0), 100)
        recordingThresholdDB = Float(-10 - ((bounded / 100) * 70))
    }

    private func save() {
        defaults.set(quality.rawValue, forKey: "quality")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(segmentMinutes, forKey: "segmentMinutes")
        defaults.set(recordingThresholdDB, forKey: "recordingThresholdDB")
        defaults.set(soundTailSeconds, forKey: "soundTailSeconds")
        defaults.set(startRecordingOnLaunch, forKey: "startRecordingOnLaunch")
    }
}
