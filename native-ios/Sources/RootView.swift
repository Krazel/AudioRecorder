import SwiftUI

struct RootView: View {
    @EnvironmentObject private var monetization: MonetizationStore
    @EnvironmentObject private var adConsent: AdConsentManager
    @State private var isBannerLoaded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TabView {
                    RecorderView()
                        .tabItem {
                            Label(L("Grabar"), systemImage: "record.circle")
                        }

                    RecordingsView()
                        .tabItem {
                            Label(L("Archivos"), systemImage: "waveform")
                        }

                    SettingsView()
                        .tabItem {
                            Label(L("Ajustes"), systemImage: "slider.horizontal.3")
                        }
                }

                if shouldPrepareBanner {
                    ZStack {
                        AdMobBannerView(isLoaded: $isBannerLoaded)
                            .frame(height: 50)
                            .opacity(isBannerLoaded ? 1 : 0)
                            .allowsHitTesting(isBannerLoaded)
                            .accessibilityHidden(!isBannerLoaded)
                    }
                    .frame(height: isBannerLoaded ? 50 : 0)
                    .clipped()
                    .animation(.easeInOut(duration: 0.2), value: isBannerLoaded)
                }
            }

            AutoStartRecorderView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .onChange(of: shouldPrepareBanner) { shouldPrepare in
            if !shouldPrepare {
                isBannerLoaded = false
            }
        }
    }

    private var shouldPrepareBanner: Bool {
        monetization.shouldShowAds && adConsent.canRequestAds && adConsent.isMobileAdsStarted
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
                Task {
                    switch phase {
                    case .active:
                        await recorder.recoverActiveRecordingIfNeeded()
                        await startIfNeeded()
                    case .background, .inactive:
                        break
                    @unknown default:
                        break
                    }
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
