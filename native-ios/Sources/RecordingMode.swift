import Foundation

enum RecordingMode: String, CaseIterable, Codable, Identifiable {
    case everything
    case voiceFocused
    case noiseFocused
    case separated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: "Todo"
        case .voiceFocused: "Voces"
        case .noiseFocused: "Ruido"
        case .separated: "Separado"
        }
    }

    var folderName: String {
        switch self {
        case .everything: "original"
        case .voiceFocused: "voice"
        case .noiseFocused: "noise"
        case .separated: "separated"
        }
    }
}
