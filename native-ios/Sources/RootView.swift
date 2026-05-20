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
                    BottomAdBanner()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
                .allowsHitTesting(false)
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

private struct BottomAdBanner: View {
    var body: some View {
        Text("AD")
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(Color.primary.opacity(0.72))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .frame(height: 40)
            .accessibilityLabel("Anuncio")
    }
}
