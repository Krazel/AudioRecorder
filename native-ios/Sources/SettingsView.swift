import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var monetization: MonetizationStore
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue
    @EnvironmentObject private var playback: AudioPlaybackService
    @EnvironmentObject private var language: AppLanguageStore
    @EnvironmentObject private var adConsent: AdConsentManager
    @Environment(\.openURL) private var openURL

    @State private var supportExpanded = false
    @State private var unlockCodeVisible = false
    @State private var confirmingDeleteAllFiles = false

    private let segmentOptions = [5, 15, 30, 60, 120]
    private let soundTailOptions = [0.0, 0.5, 1.0, 2.0, 3.0, 5.0]

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Idioma")) {
                    Picker(L("Idioma de la aplicacion"), selection: $language.selected) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.nativeName).tag(language)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(L("Grabacion")) {
                    Picker(L("Calidad"), selection: $settings.quality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }

                    Picker(L("Separar cada"), selection: $settings.segmentMinutes) {
                        ForEach(segmentOptions, id: \.self) { minutes in
                            Text(segmentTitle(minutes)).tag(minutes)
                        }
                    }

                    Picker(L("Modo"), selection: $settings.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if settings.mode == .soundActivated {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L("Sensibilidad"))
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
                                Text(L("Menos"))
                                Spacer()
                                Text(L("Mas"))
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            Text(String(format: L("La grabacion por sonido empieza cuando el nivel visible supera %d dB."), visibleThresholdDB))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Picker(L("Grabar un poco mas"), selection: $settings.soundTailSeconds) {
                            ForEach(soundTailOptions, id: \.self) { seconds in
                                Text(soundTailTitle(seconds)).tag(seconds)
                            }
                        }
                    }

                    Toggle(L("Grabar al abrir la app"), isOn: $settings.startRecordingOnLaunch)
                }

                Section(L("Archivos")) {
                    Button(role: .destructive) {
                        confirmingDeleteAllFiles = true
                    } label: {
                        Label(L("Eliminar todos los archivos"), systemImage: "trash")
                    }
                    .disabled(library.items.isEmpty)
                }

                if monetization.monetizationEnabled {
                    supportSection
                }

                if adConsent.isPrivacyOptionsRequired {
                    Section {
                        Button {
                            Task {
                                await adConsent.presentPrivacyOptions()
                            }
                        } label: {
                            Label(L("Opciones de privacidad"), systemImage: "hand.raised")
                        }
                        .disabled(adConsent.isPresentingPrivacyOptions)
                    }
                }

                Section(L("Contacto")) {
                    Button {
                        if let url = monetization.feedbackURL() {
                            openURL(url)
                        }
                    } label: {
                            Label(L("Enviar bugs o feedback"), systemImage: "envelope")
                    }
                }

                Section(L("Version")) {
                    HStack {
                        Text("Voice Recorder Pro - Audio K")
                        Spacer()
                        Text(appVersionText)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L("Ajustes"))
            .task {
                await monetization.loadProductsIfNeeded()
            }
            .alert("Voice Recorder Pro - Audio K", isPresented: messageBinding) {
                Button(L("OK"), role: .cancel) {
                    monetization.clearMessage()
                }
            } message: {
                Text(monetization.purchaseMessage ?? "")
            }
            .alert(L("Eliminar todos los archivos"), isPresented: $confirmingDeleteAllFiles) {
                Button(L("Eliminar todo"), role: .destructive) {
                    deleteAllFiles()
                }
                Button(L("Cancelar"), role: .cancel) {}
            } message: {
                Text(L("Se borraran todas las grabaciones guardadas en este iPhone. Esta accion no se puede deshacer."))
            }
            .alert("Voice Recorder Pro - Audio K", isPresented: privacyOptionsErrorBinding) {
                Button(L("OK"), role: .cancel) {
                    adConsent.clearPrivacyOptionsError()
                }
            } message: {
                Text(adConsent.privacyOptionsErrorMessage ?? "")
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
                    Label(L("Donaciones y anuncios"), systemImage: "heart.fill")
                    Spacer()
                    Text(monetization.adsRemoved ? L("Sin anuncios") : L("Opcional"))
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
                        Text(monetization.adsRemoved ? L("Sin anuncios activo") : L("Apoyar la app"))
                            .font(.subheadline.weight(.semibold))
                            Text(L("Con una aportacion mensual ayudas a mantener la app. Mientras este activa, se quitan los anuncios."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 1.1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        unlockCodeVisible.toggle()
                    }
                }

                if monetization.isLoadingProducts {
                    ProgressView(L("Cargando opciones"))
                } else if monetization.products.isEmpty {
                    Text(L("Las suscripciones se cargaran cuando los productos esten creados en App Store Connect."))
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                    Text(L("Suscripcion mensual"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                    Text(L("al mes"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Text(L("Cada opcion es una suscripcion mensual renovable. El pago se carga a tu cuenta de Apple y se renueva automaticamente cada mes, salvo que la canceles al menos 24 horas antes del final del periodo actual."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    openURL(AppMonetizationConfig.manageSubscriptionsURL)
                } label: {
                    Label(L("Gestionar o cancelar suscripcion"), systemImage: "person.crop.circle.badge.checkmark")
                }

                Button {
                    Task {
                        await monetization.restorePurchases()
                    }
                } label: {
                    Label(L("Restaurar compras"), systemImage: "arrow.clockwise")
                }

                Link(destination: AppMonetizationConfig.privacyPolicyURL) {
                    Label(L("Politica de privacidad"), systemImage: "hand.raised")
                }

                Link(destination: AppMonetizationConfig.termsOfUseURL) {
                    Label(L("Condiciones de uso"), systemImage: "doc.text")
                }

                if monetization.isManualUnlockActive {
                    Button(role: .destructive) {
                        monetization.disableManualUnlock()
                    } label: {
                        Label(L("Volver a mostrar anuncios"), systemImage: "rectangle.badge.xmark")
                    }
                }

                if unlockCodeVisible {
                    HStack {
                        TextField("", text: $monetization.unlockCode, prompt: Text(""))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            _ = monetization.applyUnlockCode()
                            unlockCodeVisible = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(monetization.unlockCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .transition(.opacity)
                }
            }
        } header: {
            Text(L("Apoyar la app"))
        }
    }

    private func segmentTitle(_ minutes: Int) -> String {
        String(format: L("%d minutos"), minutes)
    }

    private var visibleThresholdDB: Int {
        Int(round(min(max(settings.recordingThresholdDB + 80, 0), 70)))
    }

    private func soundTailTitle(_ seconds: Double) -> String {
        seconds == 0 ? L("No") : String(format: L("%.1f segundos"), seconds)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) build \(build)"
    }

    private func deleteAllFiles() {
        playback.stop()
        Task {
            await uploadQueue.removeAllJobs()
            await library.deleteAll()
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { monetization.purchaseMessage != nil },
            set: { if !$0 { monetization.clearMessage() } }
        )
    }

    private var privacyOptionsErrorBinding: Binding<Bool> {
        Binding(
            get: { adConsent.privacyOptionsErrorMessage != nil },
            set: { if !$0 { adConsent.clearPrivacyOptionsError() } }
        )
    }
}
