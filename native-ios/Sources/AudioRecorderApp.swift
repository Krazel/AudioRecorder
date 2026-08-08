import SwiftUI

@main
struct AudioRecorderApp: App {
    @StateObject private var recorder = RecorderService()
    @StateObject private var settings = RecordingSettingsStore()
    @StateObject private var library = RecordingLibrary()
    @StateObject private var uploadQueue = CloudUploadQueue()
    @StateObject private var playback = AudioPlaybackService()
    @StateObject private var monetization = MonetizationStore()
    @StateObject private var language = AppLanguageStore()
    @StateObject private var adConsent = AdConsentManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recorder)
                .environmentObject(settings)
                .environmentObject(library)
                .environmentObject(uploadQueue)
                .environmentObject(playback)
                .environmentObject(monetization)
                .environmentObject(language)
                .environmentObject(adConsent)
                .environment(\.locale, Locale(identifier: language.selected.rawValue))
                .task {
                    await adConsent.prepareForAds()
                    await library.load()
                    await uploadQueue.load()
                }
        }
    }
}
