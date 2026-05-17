import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: RecordingSettingsStore
    @Environment(\.openURL) private var openURL

    @State private var setupProvider: CloudProvider?

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

                    Picker("Modo", selection: $settings.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Picker("Separar cada", selection: $settings.segmentMinutes) {
                        ForEach(segmentOptions, id: \.self) { minutes in
                            Text(segmentTitle(minutes)).tag(minutes)
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
                    .onChange(of: settings.cloudProvider) { provider in
                        if provider != .none {
                            setupProvider = provider
                        }
                    }

                    if settings.uploadAutomatically && settings.cloudProvider == .customServer {
                        TextField("https://tu-servidor.com/upload", text: $settings.customUploadEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        SecureField("Token o API key opcional", text: $settings.customUploadToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    if settings.uploadAutomatically && settings.cloudProvider != .none {
                        Button {
                            setupProvider = settings.cloudProvider
                        } label: {
                            Label(providerSetupButtonTitle, systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
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
            .sheet(item: $setupProvider) { provider in
                UploadProviderSetupView(
                    provider: provider,
                    endpoint: $settings.customUploadEndpoint,
                    token: $settings.customUploadToken,
                    openURL: openURL
                )
            }
        }
    }

    private var providerSetupButtonTitle: String {
        switch settings.cloudProvider {
        case .customServer:
            "Configurar acceso"
        case .googleDrive, .oneDrive:
            "Iniciar sesion"
        case .none:
            "Configurar"
        }
    }

    private func segmentTitle(_ minutes: Int) -> String {
        minutes == 0 ? "No separar" : "\(minutes) minutos"
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) build \(build)"
    }
}

private struct UploadProviderSetupView: View {
    let provider: CloudProvider
    @Binding var endpoint: String
    @Binding var token: String
    let openURL: OpenURLAction

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch provider {
                case .customServer:
                    Section("Servidor propio") {
                        TextField("https://tu-servidor.com/upload", text: $endpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        SecureField("Token o API key opcional", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                case .googleDrive:
                    Section("Google Drive") {
                        Button {
                            openURL(URL(string: "https://accounts.google.com/")!)
                        } label: {
                            Label("Abrir inicio de sesion", systemImage: "safari")
                        }
                    }
                case .oneDrive:
                    Section("OneDrive") {
                        Button {
                            openURL(URL(string: "https://login.microsoftonline.com/")!)
                        } label: {
                            Label("Abrir inicio de sesion", systemImage: "safari")
                        }
                    }
                case .none:
                    EmptyView()
                }
            }
            .navigationTitle(provider.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}
