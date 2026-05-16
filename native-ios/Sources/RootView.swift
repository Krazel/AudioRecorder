import SwiftUI

struct RootView: View {
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
    }
}
