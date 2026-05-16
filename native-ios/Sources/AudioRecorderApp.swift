import SwiftUI

@main
struct AudioRecorderApp: App {
    @StateObject private var recorder = RecorderService()
    @StateObject private var settings = RecordingSettingsStore()
    @StateObject private var library = RecordingLibrary()
    @StateObject private var uploadQueue = CloudUploadQueue()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recorder)
                .environmentObject(settings)
                .environmentObject(library)
                .environmentObject(uploadQueue)
                .task {
                    await library.load()
                    await uploadQueue.load()
                }
        }
    }
}
