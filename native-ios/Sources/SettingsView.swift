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
                            Text("Umbral")
                            Spacer()
                            Text("\(Int(settings.recordingThresholdDB)) dBFS")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.recordingThresholdDB) },
                                set: { settings.recordingThresholdDB = Float($0) }
                            ),
                            in: -80 ... -10,
                            step: 1
                        )
                        Text("Es dBFS: 0 es el maximo digital, por eso el nivel normal aparece en negativo. Mas bajo = mas sensible.")
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

                Section("Modo por sonido") {
                    Text("La app no identifica voz real todavia. El modo Por sonido guarda cualquier audio que supere el umbral dBFS y compacta los silencios.")
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
