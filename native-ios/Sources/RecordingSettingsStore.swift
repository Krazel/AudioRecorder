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

    @Published var cloudProvider: CloudProvider {
        didSet { save() }
    }

    @Published var uploadAutomatically: Bool {
        didSet { save() }
    }

    @Published var recordingThresholdDB: Float {
        didSet { save() }
    }

    @Published var startRecordingOnLaunch: Bool {
        didSet { save() }
    }

    @Published var customUploadEndpoint: String {
        didSet { save() }
    }

    @Published var customUploadToken: String {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    init() {
        let storedSegmentMinutes = defaults.object(forKey: "segmentMinutes") as? Int
        let storedThreshold = defaults.object(forKey: "recordingThresholdDB") as? Float
        quality = AudioQuality(rawValue: defaults.string(forKey: "quality") ?? "") ?? .medium
        mode = RecordingMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .everything
        segmentMinutes = storedSegmentMinutes ?? 0
        cloudProvider = CloudProvider(rawValue: defaults.string(forKey: "cloudProvider") ?? "") ?? .none
        uploadAutomatically = defaults.object(forKey: "uploadAutomatically") as? Bool ?? false
        recordingThresholdDB = storedThreshold ?? -55
        startRecordingOnLaunch = defaults.object(forKey: "startRecordingOnLaunch") as? Bool ?? false
        customUploadEndpoint = defaults.string(forKey: "customUploadEndpoint") ?? ""
        customUploadToken = defaults.string(forKey: "customUploadToken") ?? ""
    }

    var segmentDuration: TimeInterval {
        guard segmentMinutes > 0 else { return .infinity }
        return TimeInterval(segmentMinutes * 60)
    }

    var customUploadEndpointURL: URL? {
        guard let components = URLComponents(string: customUploadEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }
        return components.url
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
        defaults.set(cloudProvider.rawValue, forKey: "cloudProvider")
        defaults.set(uploadAutomatically, forKey: "uploadAutomatically")
        defaults.set(recordingThresholdDB, forKey: "recordingThresholdDB")
        defaults.set(startRecordingOnLaunch, forKey: "startRecordingOnLaunch")
        defaults.set(customUploadEndpoint, forKey: "customUploadEndpoint")
        defaults.set(customUploadToken, forKey: "customUploadToken")
    }
}
