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
                            Text("\(Int(-settings.recordingThresholdDB)) dB")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(-settings.recordingThresholdDB) },
                                set: { settings.recordingThresholdDB = -Float($0) }
                            ),
                            in: 10 ... 80,
                            step: 1
                        )
                        Text("Mas alto = mas sensible. Solo afecta a Voces y Ruido.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                Section("Modos") {
                    Text("Ahora mismo Voces y Ruido usan el mismo baremo de volumen: guardan solo cuando hay sonido por encima del umbral. Separado todavia no separa voz y ruido en pistas distintas; guarda el audio original para procesarlo despues.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Version") {
                    HStack {
                        Text("AudioRecorder")
                        Spacer()
                        Text(appVersionText)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) build \(build)"
    }
}
