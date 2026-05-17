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
                            Text("Sensibilidad")
                            Spacer()
                            Text("\(settings.sensitivityPercent)%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.sensitivityPercent) },
                                set: { settings.setSensitivityPercent($0) }
                            ),
                            in: 0 ... 100,
                            step: 1
                        )
                        HStack {
                            Text("Menos")
                            Spacer()
                            Text("Mas")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        Text("Umbral tecnico: \(Int(settings.recordingThresholdDB)) dBFS. dBFS es nivel digital: 0 es el maximo y los niveles normales son negativos.")
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

                    if settings.uploadAutomatically && settings.cloudProvider == .customServer {
                        TextField("https://tu-servidor.com/upload", text: $settings.customUploadEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        Text("La app enviara el archivo como multipart/form-data en el campo file. Tambien incluye recording_id y provider.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notas") {
                    Text("Servidor propio ya permite probar subidas externas con un endpoint HTTPS. Google Drive y OneDrive siguen preparados para conectar OAuth y sus APIs reales antes de publicar.")
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
                        Text("Grabadora")
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
