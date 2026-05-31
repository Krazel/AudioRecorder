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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var recorder: RecorderService
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue

    var body: some View {
        Color.clear
            .task {
                await startIfNeeded()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task {
                    await recorder.recoverActiveRecordingIfNeeded()
                    await startIfNeeded()
                }
            }
    }

    private func startIfNeeded() async {
        guard (settings.startRecordingOnLaunch || recorder.shouldResumePersistedRecording),
              !recorder.isRecording else {
            return
        }
        await recorder.start(settings: settings, library: library, uploadQueue: uploadQueue)
    }
}
