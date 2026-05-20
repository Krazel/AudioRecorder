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
                items = []
                return
            }
            let data = try Data(contentsOf: indexURL)
            items = try JSONDecoder().decode([RecordingItem].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            items = []
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

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
