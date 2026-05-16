import Foundation

struct UploadJob: Identifiable, Codable, Equatable {
    let id: UUID
    let recordingID: UUID
    let fileURL: URL
    let provider: CloudProvider
    var attempts: Int
    var state: UploadState
}

@MainActor
final class CloudUploadQueue: ObservableObject {
    @Published private(set) var jobs: [UploadJob] = []

    private var queueURL: URL {
        RecordingStorage.rootDirectory.appendingPathComponent("upload-queue.json")
    }

    func load() async {
        do {
            try RecordingStorage.ensureDirectories()
            guard FileManager.default.fileExists(atPath: queueURL.path) else {
                jobs = []
                return
            }
            let data = try Data(contentsOf: queueURL)
            jobs = try JSONDecoder().decode([UploadJob].self, from: data)
        } catch {
            jobs = []
        }
    }

    func enqueue(recording: RecordingItem, provider: CloudProvider) async {
        guard provider != .none else { return }
        let job = UploadJob(
            id: UUID(),
            recordingID: recording.id,
            fileURL: recording.fileURL,
            provider: provider,
            attempts: 0,
            state: .queued
        )
        jobs.append(job)
        await save()
    }

    func processNext() async {
        guard let index = jobs.firstIndex(where: { $0.state == .queued || $0.state == .failed }) else {
            return
        }

        jobs[index].state = .uploading
        jobs[index].attempts += 1
        await save()

        do {
            let uploader = CloudUploaderFactory.uploader(for: jobs[index].provider)
            try await uploader.upload(fileURL: jobs[index].fileURL)
            jobs[index].state = .uploaded
        } catch {
            jobs[index].state = .failed
        }
        await save()
    }

    func removeJobs(recordingID: UUID) async {
        jobs.removeAll { $0.recordingID == recordingID }
        await save()
    }

    private func save() async {
        do {
            try RecordingStorage.ensureDirectories()
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: queueURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save upload queue: \(error)")
        }
    }
}
