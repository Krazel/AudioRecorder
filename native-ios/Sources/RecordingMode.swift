import Foundation

enum RecordingMode: String, CaseIterable, Codable, Identifiable {
    case everything
    case soundActivated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: "Todo"
        case .soundActivated: "Por sonido"
        }
    }

    var folderName: String {
        switch self {
        case .everything: "original"
        case .soundActivated: "sound"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "everything":
            self = .everything
        case "voiceFocused", "noiseFocused", "separated", "soundActivated":
            self = .soundActivated
        default:
            self = .soundActivated
        }
    }
}
