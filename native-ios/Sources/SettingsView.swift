import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var monetization: MonetizationStore
    @Environment(\.openURL) private var openURL

    @State private var supportExpanded = false

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

                if monetization.monetizationEnabled {
                    supportSection
                }

                Section("Contacto") {
                    Button {
                        if let url = monetization.feedbackURL() {
                            openURL(url)
                        }
                    } label: {
                        Label("Enviar bugs o feedback", systemImage: "envelope")
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
            .task {
                await monetization.loadProductsIfNeeded()
            }
            .alert("AudioRecorder", isPresented: messageBinding) {
                Button("OK", role: .cancel) {
                    monetization.clearMessage()
                }
            } message: {
                Text(monetization.purchaseMessage ?? "")
            }
        }
    }

    private var supportSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    supportExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Donaciones y anuncios", systemImage: "heart.fill")
                    Spacer()
                    Text(monetization.adsRemoved ? "Sin anuncios" : "Opcional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(supportExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }

            if supportExpanded {
                HStack(spacing: 12) {
                    Image(systemName: monetization.adsRemoved ? "checkmark.seal.fill" : "rectangle.badge.xmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(monetization.adsRemoved ? .green : .accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(monetization.adsRemoved ? "Sin anuncios activo" : "Con anuncio discreto abajo")
                            .font(.subheadline.weight(.semibold))
                        Text("Con una aportacion mensual ayudas a mantener la app. Mientras este activa, se quitan los anuncios.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if monetization.isLoadingProducts {
                    ProgressView("Cargando opciones")
                } else if monetization.products.isEmpty {
                    Text("Las suscripciones se cargaran cuando los productos esten creados en App Store Connect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monetization.products, id: \.id) { product in
                        Button {
                            Task {
                                await monetization.purchase(product)
                            }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                Button {
                    Task {
                        await monetization.restorePurchases()
                    }
                } label: {
                    Label("Restaurar compras", systemImage: "arrow.clockwise")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Codigo para quitar anuncios")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        TextField("Codigo", text: $monetization.unlockCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("Aplicar") {
                            _ = monetization.applyUnlockCode()
                        }
                        .disabled(monetization.unlockCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        } header: {
            Text("Apoyar la app")
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

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { monetization.purchaseMessage != nil },
            set: { if !$0 { monetization.clearMessage() } }
        )
    }
}
