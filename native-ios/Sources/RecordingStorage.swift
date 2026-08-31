import Foundation

enum RecordingStorage {
    static let backgroundRecordingProtection = FileProtectionType.completeUntilFirstUserAuthentication

    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Recordings", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try applyBackgroundRecordingProtection(to: rootDirectory)
        for mode in RecordingMode.allCases {
            let directory = rootDirectory.appendingPathComponent(mode.folderName, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try applyBackgroundRecordingProtection(to: directory)
        }
    }

    static func prepareOpenSegmentForBackgroundRecording(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [NSFilePathErrorKey: url.path]
            )
        }
        try applyBackgroundRecordingProtection(to: url)
    }

    static func nextSegmentURL(mode: RecordingMode, quality: AudioQuality, date: Date = Date()) throws -> URL {
        try ensureDirectories()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let directory = rootDirectory
            .appendingPathComponent(mode.folderName, isDirectory: true)
        let baseName = "\(formatter.string(from: date))_\(mode.rawValue)_\(UUID().uuidString.prefix(8))"
        var url = directory.appendingPathComponent(baseName).appendingPathExtension(quality.fileExtension)
        var attempt = 1

        while FileManager.default.fileExists(atPath: url.path) {
            url = directory
                .appendingPathComponent("\(baseName)-\(attempt)")
                .appendingPathExtension(quality.fileExtension)
            attempt += 1
        }

        return url
    }

    private static func applyBackgroundRecordingProtection(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: backgroundRecordingProtection],
            ofItemAtPath: url.path
        )
    }
}
