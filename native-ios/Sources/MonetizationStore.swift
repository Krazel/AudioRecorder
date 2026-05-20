import Foundation
import StoreKit

enum AppMonetizationConfig {
    static let adsEnabled = true
    static let supportEmail = "coderappskrazel@gmail.com"
    static let monthlySupportProductIDs = [
        "com.dmkr.audio.support.monthly.099",
        "com.dmkr.audio.support.monthly.299",
        "com.dmkr.audio.support.monthly.499"
    ]
    static let manualUnlockCodes = [
        "AUDIO-SIN-ANUNCIOS",
        "KRAZEL-AUDIO",
        "AUDIO-2026"
    ]
}

@MainActor
final class MonetizationStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseMessage: String?
    @Published var unlockCode = ""
    @Published var adsRemoved: Bool {
        didSet { defaults.set(adsRemoved, forKey: adsRemovedKey) }
    }

    private let defaults = UserDefaults.standard
    private let adsRemovedKey = "audio.native.adsRemoved.v1"
    private var transactionUpdatesTask: Task<Void, Never>?

    var monetizationEnabled: Bool {
        AppMonetizationConfig.adsEnabled
    }

    var shouldShowAds: Bool {
        monetizationEnabled && !adsRemoved
    }

    init() {
        adsRemoved = defaults.object(forKey: adsRemovedKey) as? Bool ?? false
        transactionUpdatesTask = listenForTransactions()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProductsIfNeeded() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: AppMonetizationConfig.monthlySupportProductIDs)
            await refreshEntitlements()
        } catch {
            purchaseMessage = "No se han podido cargar las opciones de apoyo."
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                adsRemoved = true
                purchaseMessage = "Gracias. Los anuncios se han quitado."
                await transaction.finish()
            case .pending:
                purchaseMessage = "La compra queda pendiente de aprobacion."
            case .userCancelled:
                break
            @unknown default:
                purchaseMessage = "No se ha podido completar la compra."
            }
        } catch {
            purchaseMessage = "No se ha podido completar la compra."
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseMessage = adsRemoved ? "Compras restauradas." : "No hay una suscripcion activa para restaurar."
        } catch {
            purchaseMessage = "No se han podido restaurar las compras."
        }
    }

    func applyUnlockCode() -> Bool {
        let normalized = unlockCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard AppMonetizationConfig.manualUnlockCodes.contains(normalized) else {
            purchaseMessage = "Codigo no valido."
            return false
        }
        adsRemoved = true
        unlockCode = ""
        purchaseMessage = "Codigo aplicado. Los anuncios se han quitado."
        return true
    }

    func clearMessage() {
        purchaseMessage = nil
    }

    func feedbackURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppMonetizationConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "AudioRecorder - bugs o feedback"),
            URLQueryItem(name: "body", value: feedbackBody)
        ]
        return components.url
    }

    private var feedbackBody: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\n\n---\nAudioRecorder v\(version) build \(build)"
    }

    private func refreshEntitlements() async {
        var hasActiveSupport = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  AppMonetizationConfig.monthlySupportProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            hasActiveSupport = true
        }
        if hasActiveSupport {
            adsRemoved = true
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                if AppMonetizationConfig.monthlySupportProductIDs.contains(transaction.productID) {
                    self.adsRemoved = transaction.revocationDate == nil
                }
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

private enum StoreError: Error {
    case failedVerification
}
