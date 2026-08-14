import Foundation
import StoreKit

enum AppMonetizationConfig {
    static let adsEnabled = true
    static let supportEmail = "coderappskrazel@gmail.com"
    static var adMobIOSBannerUnitID: String {
        (Bundle.main.object(forInfoDictionaryKey: "ADMOBBannerUnitID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    static let monthlySupportProductIDs = [
        "com.dmkr.audio.support.monthly.099",
        "com.dmkr.audio.support.monthly.299",
        "com.dmkr.audio.support.monthly.499",
        "com.dmkr.audio.support.monthly.999",
        "com.dmkr.audio.support.monthly.1499",
        "com.dmkr.audio.support.monthly.2999",
        "com.dmkr.audio.support.monthly.50"
    ]
    static let privacyPolicyURL = URL(string: "https://krazel.github.io/audio-recorder/privacy/")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}

@MainActor
final class MonetizationStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseMessage: String?
    @Published var adsRemoved: Bool {
        didSet { defaults.set(adsRemoved, forKey: adsRemovedKey) }
    }

    private let defaults = UserDefaults.standard
    private let adsRemovedKey = "audio.native.adsRemoved.v1"
    private let adsRemovedSourceKey = "audio.native.adsRemovedSource.v1"
    private var transactionUpdatesTask: Task<Void, Never>?

    var monetizationEnabled: Bool {
        AppMonetizationConfig.adsEnabled
    }

    var shouldShowAds: Bool {
        monetizationEnabled && !adsRemoved
    }

    init() {
        adsRemoved = defaults.object(forKey: adsRemovedKey) as? Bool ?? false
        removeLegacyManualUnlockIfNeeded()
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
            let productOrder = Dictionary(
                uniqueKeysWithValues: AppMonetizationConfig.monthlySupportProductIDs.enumerated().map { ($0.element, $0.offset) }
            )
            products = try await Product.products(for: AppMonetizationConfig.monthlySupportProductIDs)
                .sorted { (productOrder[$0.id] ?? Int.max) < (productOrder[$1.id] ?? Int.max) }
            await refreshEntitlements()
        } catch {
            purchaseMessage = L("No se han podido cargar las opciones de apoyo.")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                adsRemoved = true
                defaults.set(AdsRemovedSource.subscription.rawValue, forKey: adsRemovedSourceKey)
                purchaseMessage = L("Gracias. Los anuncios se han quitado.")
                await transaction.finish()
            case .pending:
                purchaseMessage = L("La compra queda pendiente de aprobacion.")
            case .userCancelled:
                break
            @unknown default:
                purchaseMessage = L("No se ha podido completar la compra.")
            }
        } catch {
            purchaseMessage = L("No se ha podido completar la compra.")
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseMessage = adsRemoved ? L("Compras restauradas.") : L("No hay una suscripcion activa para restaurar.")
        } catch {
            purchaseMessage = L("No se han podido restaurar las compras.")
        }
    }

    func clearMessage() {
        purchaseMessage = nil
    }

    func feedbackURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppMonetizationConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Voice Recorder Pro - Audio K - bugs o feedback"),
            URLQueryItem(name: "body", value: feedbackBody)
        ]
        return components.url
    }

    private var feedbackBody: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\n\n---\nVoice Recorder Pro - Audio K v\(version) build \(build)"
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
            defaults.set(AdsRemovedSource.subscription.rawValue, forKey: adsRemovedSourceKey)
        } else if defaults.string(forKey: adsRemovedSourceKey) == AdsRemovedSource.subscription.rawValue {
            adsRemoved = false
            defaults.removeObject(forKey: adsRemovedSourceKey)
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                if AppMonetizationConfig.monthlySupportProductIDs.contains(transaction.productID) {
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func removeLegacyManualUnlockIfNeeded() {
        guard defaults.string(forKey: adsRemovedSourceKey) == "manual" else { return }
        adsRemoved = false
        defaults.removeObject(forKey: adsRemovedSourceKey)
        defaults.removeObject(forKey: "audio.native.manualUnlockGeneration.v1")
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

private enum AdsRemovedSource: String {
    case subscription
}
