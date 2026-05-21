import SwiftUI
import GoogleMobileAds

@main
struct AudioRecorderApp: App {
    @StateObject private var recorder = RecorderService()
    @StateObject private var settings = RecordingSettingsStore()
    @StateObject private var library = RecordingLibrary()
    @StateObject private var uploadQueue = CloudUploadQueue()
    @StateObject private var playback = AudioPlaybackService()
    @StateObject private var monetization = MonetizationStore()

    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recorder)
                .environmentObject(settings)
                .environmentObject(library)
                .environmentObject(uploadQueue)
                .environmentObject(playback)
                .environmentObject(monetization)
                .task {
                    await library.load()
                    await uploadQueue.load()
                }
        }
    }
}
