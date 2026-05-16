import Foundation

enum RecordingStorage {
    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Recordings", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        for mode in RecordingMode.allCases {
            try FileManager.default.createDirectory(
                at: rootDirectory.appendingPathComponent(mode.folderName, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    static func nextSegmentURL(mode: RecordingMode, quality: AudioQuality, date: Date = Date()) throws -> URL {
        try ensureDirectories()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "\(formatter.string(from: date))_\(mode.rawValue).\(quality.fileExtension)"
        return rootDirectory
            .appendingPathComponent(mode.folderName, isDirectory: true)
            .appendingPathComponent(name)
    }
}
