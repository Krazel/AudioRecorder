import SwiftUI

struct RootView: View {
    @EnvironmentObject private var recorder: RecorderService
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue

    @State private var attemptedAutoStart = false

    var body: some View {
        TabView {
            RecorderView()
                .tabItem {
                    Label("Grabar", systemImage: "record.circle")
                }

            RecordingsView()
                .tabItem {
                    Label("Archivos", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "slider.horizontal.3")
                }
        }
        .task {
            guard settings.startRecordingOnLaunch, !attemptedAutoStart else { return }
            attemptedAutoStart = true
            await recorder.start(settings: settings, library: library, uploadQueue: uploadQueue)
        }
    }
}
