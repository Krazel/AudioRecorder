import SwiftUI

struct RootView: View {
    @EnvironmentObject private var monetization: MonetizationStore

    var body: some View {
        ZStack(alignment: .bottom) {
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

            if monetization.shouldShowAds {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    AdMobBannerView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            AutoStartRecorderView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}

private struct AutoStartRecorderView: View {
    @EnvironmentObject private var recorder: RecorderService
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue

    @State private var attemptedAutoStart = false

    var body: some View {
        Color.clear
            .task {
                guard settings.startRecordingOnLaunch, !attemptedAutoStart else { return }
                attemptedAutoStart = true
                await recorder.start(settings: settings, library: library, uploadQueue: uploadQueue)
            }
    }
}
