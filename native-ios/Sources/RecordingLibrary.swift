import AVFoundation
import Foundation

@MainActor
final class RecordingLibrary: ObservableObject {
    @Published private(set) var items: [RecordingItem] = []

    private var indexURL: URL {
        RecordingStorage.rootDirectory.appendingPathComponent("recordings.json")
    }

    func load() async {
        do {
            try RecordingStorage.ensureDirectories()
            guard FileManager.default.fileExists(atPath: indexURL.path) else {
                items = await recoverUnindexedRecordings(from: [])
                    .sorted { $0.createdAt > $1.createdAt }
                if !items.isEmpty {
                    saveImmediately()
                }
                return
            }
            let data = try Data(contentsOf: indexURL)
            let decodedItems = try JSONDecoder().decode([RecordingItem].self, from: data)
            let repairedItems = decodedItems
                .map(repairFileURLIfNeeded)
                .sorted { $0.createdAt > $1.createdAt }
            items = await recoverUnindexedRecordings(from: repairedItems)
                .sorted { $0.createdAt > $1.createdAt }
            if items != decodedItems {
                saveImmediately()
            }
        } catch {
            items = await recoverUnindexedRecordings(from: [])
                .sorted { $0.createdAt > $1.createdAt }
            if !items.isEmpty {
                saveImmediately()
            }
        }
    }

    func add(_ item: RecordingItem) async {
        addImmediately(item)
    }

    func addImmediately(_ item: RecordingItem) {
        if items.contains(where: { $0.id == item.id }) {
            return
        }
        items.insert(item, at: 0)
        saveImmediately()
    }

    func updateUploadState(id: UUID, state: UploadState) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].uploadState = state
        await save()
    }

    func setFavorite(ids: Set<UUID>, isFavorite: Bool) async {
        guard !ids.isEmpty else { return }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isFavorite = isFavorite
        }
        await save()
    }

    func delete(_ item: RecordingItem) async {
        playbackSafeDelete(fileURL: item.fileURL)
        items.removeAll { $0.id == item.id }
        await save()
    }

    func deleteAll() async {
        for item in items {
            playbackSafeDelete(fileURL: item.fileURL)
        }
        items.removeAll()
        await save()
    }

    func rename(_ item: RecordingItem, to rawName: String) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let cleanName = sanitizedFileName(rawName)
        guard !cleanName.isEmpty else { return }

        let oldURL = items[index].fileURL
        let newURL = oldURL
            .deletingLastPathComponent()
            .appendingPathComponent(cleanName)
            .appendingPathExtension(oldURL.pathExtension)

        do {
            if oldURL != newURL {
                if FileManager.default.fileExists(atPath: newURL.path) {
                    try FileManager.default.removeItem(at: newURL)
                }
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                items[index].fileURL = newURL
            }
            items[index].customName = cleanName
            await save()
        } catch {
            assertionFailure("Failed to rename recording: \(error)")
        }
    }

    private func save() async {
        saveImmediately()
    }

    private func saveImmediately() {
        do {
            try RecordingStorage.ensureDirectories()
            let data = try JSONEncoder().encode(items)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save recording index: \(error)")
        }
    }

    private func playbackSafeDelete(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func repairFileURLIfNeeded(_ item: RecordingItem) -> RecordingItem {
        guard !FileManager.default.fileExists(atPath: item.fileURL.path) else { return item }

        let fileName = item.fileURL.lastPathComponent
        let preferredURL = RecordingStorage.rootDirectory
            .appendingPathComponent(item.mode.folderName, isDirectory: true)
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: preferredURL.path) {
            var repairedItem = item
            repairedItem.fileURL = preferredURL
            return repairedItem
        }

        for mode in RecordingMode.allCases {
            let candidateURL = RecordingStorage.rootDirectory
                .appendingPathComponent(mode.folderName, isDirectory: true)
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                var repairedItem = item
                repairedItem.fileURL = candidateURL
                return repairedItem
            }
        }

        return item
    }

    private func recoverUnindexedRecordings(from loadedItems: [RecordingItem]) async -> [RecordingItem] {
        var recoveredItems = loadedItems
        var knownPaths = Set(loadedItems.map { $0.fileURL.standardizedFileURL.path })

        for mode in RecordingMode.allCases {
            let directory = RecordingStorage.rootDirectory.appendingPathComponent(mode.folderName, isDirectory: true)
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for fileURL in fileURLs {
                let standardizedPath = fileURL.standardizedFileURL.path
                guard !knownPaths.contains(standardizedPath),
                      isRecoverableAudioFile(fileURL),
                      isRegularFile(fileURL) else {
                    continue
                }

                let duration = await mediaDuration(for: fileURL)
                guard duration > 0.02 else { continue }

                recoveredItems.append(
                    RecordingItem(
                        id: UUID(),
                        createdAt: creationDate(for: fileURL),
                        duration: duration,
                        fileURL: fileURL,
                        mode: mode,
                        quality: recoveredQuality(for: fileURL),
                        uploadState: .localOnly,
                        customName: nil
                    )
                )
                knownPaths.insert(standardizedPath)
            }
        }

        return recoveredItems
    }

    private func isRecoverableAudioFile(_ url: URL) -> Bool {
        ["m4a", "caf"].contains(url.pathExtension.lowercased())
    }

    private func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private func mediaDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            return seconds.isFinite ? seconds : 0
        } catch {
            return 0
        }
    }

    private func creationDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate ?? Date()
    }

    private func recoveredQuality(for url: URL) -> AudioQuality {
        url.pathExtension.lowercased() == "caf" ? .high : .medium
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
