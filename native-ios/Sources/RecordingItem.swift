import Foundation

struct RecordingItem: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    var fileURL: URL
    let mode: RecordingMode
    let quality: AudioQuality
    var uploadState: UploadState
    var customName: String?

    var title: String {
        if let customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var fileSizeBytes: Int64 {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
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
