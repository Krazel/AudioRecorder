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
    var isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case duration
        case fileURL
        case mode
        case quality
        case uploadState
        case customName
        case isFavorite
    }

    init(
        id: UUID,
        createdAt: Date,
        duration: TimeInterval,
        fileURL: URL,
        mode: RecordingMode,
        quality: AudioQuality,
        uploadState: UploadState,
        customName: String?,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.fileURL = fileURL
        self.mode = mode
        self.quality = quality
        self.uploadState = uploadState
        self.customName = customName
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        mode = try container.decode(RecordingMode.self, forKey: .mode)
        quality = try container.decode(AudioQuality.self, forKey: .quality)
        uploadState = try container.decode(UploadState.self, forKey: .uploadState)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

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
