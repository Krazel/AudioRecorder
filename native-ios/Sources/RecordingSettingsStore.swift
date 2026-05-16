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

    private let defaults = UserDefaults.standard

    init() {
        quality = AudioQuality(rawValue: defaults.string(forKey: "quality") ?? "") ?? .medium
        mode = RecordingMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .everything
        segmentMinutes = defaults.integer(forKey: "segmentMinutes")
        if segmentMinutes == 0 {
            segmentMinutes = 30
        }
        cloudProvider = CloudProvider(rawValue: defaults.string(forKey: "cloudProvider") ?? "") ?? .none
        uploadAutomatically = defaults.object(forKey: "uploadAutomatically") as? Bool ?? false
    }

    var segmentDuration: TimeInterval {
        TimeInterval(segmentMinutes * 60)
    }

    private func save() {
        defaults.set(quality.rawValue, forKey: "quality")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(segmentMinutes, forKey: "segmentMinutes")
        defaults.set(cloudProvider.rawValue, forKey: "cloudProvider")
        defaults.set(uploadAutomatically, forKey: "uploadAutomatically")
    }
}
