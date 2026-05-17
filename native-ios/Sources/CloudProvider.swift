import Foundation

enum CloudProvider: String, CaseIterable, Codable, Identifiable {
    case none
    case iCloudDrive
    case googleDrive
    case oneDrive
    case customServer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Sin subida"
        case .iCloudDrive: "iCloud Drive / Archivos"
        case .googleDrive: "Google Drive"
        case .oneDrive: "OneDrive"
        case .customServer: "Servidor propio"
        }
    }
}
