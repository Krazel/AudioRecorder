import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: RecordingSettingsStore

    private let segmentOptions = [5, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section("Grabación") {
                    Picker("Calidad", selection: $settings.quality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }

                    Picker("Modo", selection: $settings.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Picker("Separar cada", selection: $settings.segmentMinutes) {
                        ForEach(segmentOptions, id: \.self) { minutes in
                            Text("\(minutes) minutos").tag(minutes)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Baremo")
                            Spacer()
                            Text("\(Int(settings.recordingThresholdDB)) dB")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.recordingThresholdDB) },
                                set: { settings.recordingThresholdDB = Float($0) }
                            ),
                            in: -70 ... -10,
                            step: 1
                        )
                    }

                    Toggle("Grabar al abrir la app", isOn: $settings.startRecordingOnLaunch)
                }

                Section("Subida automatica") {
                    Toggle("Subir al terminar cada segmento", isOn: $settings.uploadAutomatically)

                    Picker("Destino", selection: $settings.cloudProvider) {
                        ForEach(CloudProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .disabled(!settings.uploadAutomatically)
                }

                Section("Notas") {
                    Text("Google Drive y OneDrive quedan preparados como proveedores. Falta conectar OAuth y las APIs reales antes de publicar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
