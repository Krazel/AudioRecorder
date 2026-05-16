import Foundation

struct RecordingItem: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let fileURL: URL
    let mode: RecordingMode
    let quality: AudioQuality
    var uploadState: UploadState

    var title: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

enum UploadState: String, Codable, Equatable {
    case localOnly
    case queued
    case uploading
    case uploaded
    case failed

    var title: String {
        switch self {
        case .localOnly: "Local"
        case .queued: "En cola"
        case .uploading: "Subiendo"
        case .uploaded: "Subido"
        case .failed: "Error"
        }
    }
}
