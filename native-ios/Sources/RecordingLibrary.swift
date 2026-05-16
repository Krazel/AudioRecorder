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
        items.insert(item, at: 0)
        await save()
    }

    func updateUploadState(id: UUID, state: UploadState) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].uploadState = state
        await save()
    }

    private func save() async {
        do {
            try RecordingStorage.ensureDirectories()
            let data = try JSONEncoder().encode(items)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save recording index: \(error)")
        }
    }
}
