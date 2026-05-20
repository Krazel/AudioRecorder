import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: RecordingSettingsStore

    private let segmentOptions = [0, 5, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section("Grabación") {
                    Picker("Calidad", selection: $settings.quality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }

                    Picker("Separar cada", selection: $settings.segmentMinutes) {
                        ForEach(segmentOptions, id: \.self) { minutes in
                            Text(segmentTitle(minutes)).tag(minutes)
                        }
                    }

                    Picker("Modo", selection: $settings.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if settings.mode == .soundActivated {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sensibilidad")
                                Spacer()
                                Text("\(visibleThresholdDB) dB")
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
                            Text("La grabacion por sonido empieza cuando el nivel visible supera \(visibleThresholdDB) dB.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Grabar al abrir la app", isOn: $settings.startRecordingOnLaunch)
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

    private func segmentTitle(_ minutes: Int) -> String {
        minutes == 0 ? "No separar" : "\(minutes) minutos"
    }

    private var visibleThresholdDB: Int {
        Int(round(min(max(settings.recordingThresholdDB + 80, 0), 70)))
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) build \(build)"
    }
}
