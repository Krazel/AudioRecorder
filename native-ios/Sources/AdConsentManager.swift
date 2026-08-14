import AppTrackingTransparency
import Combine
import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

@MainActor
final class AdConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var isMobileAdsStarted = false
    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var isPresentingPrivacyOptions = false
    @Published private(set) var privacyOptionsErrorMessage: String?

    private var didRequestConsentInformation = false
    private var didRequestTrackingAuthorization = false
    private var isMobileAdsStarting = false

    func prepareForAds() async {
        guard !didRequestConsentInformation else { return }
        didRequestConsentInformation = true

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        } catch {
            refreshConsentState()
            await requestTrackingAuthorizationIfNeeded()
            await startMobileAdsIfAllowed()
            return
        }

        refreshConsentState()

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // UMP can retain a valid choice from an earlier session even when refreshing
            // or presenting a new form fails, so its own canRequestAds value stays authoritative.
        }

        refreshConsentState()
        await requestTrackingAuthorizationIfNeeded()
        await startMobileAdsIfAllowed()
    }

    func presentPrivacyOptions() async {
        guard isPrivacyOptionsRequired, !isPresentingPrivacyOptions else { return }
        isPresentingPrivacyOptions = true
        defer { isPresentingPrivacyOptions = false }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            refreshConsentState()
            await requestTrackingAuthorizationIfNeeded()
            await startMobileAdsIfAllowed()
        } catch {
            privacyOptionsErrorMessage = L("No se pudieron abrir las opciones de privacidad.")
        }
    }

    func clearPrivacyOptionsError() {
        privacyOptionsErrorMessage = nil
    }

    private func refreshConsentState() {
        let consentInformation = ConsentInformation.shared
        canRequestAds = consentInformation.canRequestAds
        isPrivacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        guard canRequestAds, !didRequestTrackingAuthorization else { return }
        await waitUntilApplicationIsActive()

        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        didRequestTrackingAuthorization = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private func waitUntilApplicationIsActive() async {
        guard UIApplication.shared.applicationState != .active else { return }

        for await _ in NotificationCenter.default.notifications(
            named: UIApplication.didBecomeActiveNotification
        ) {
            break
        }
    }

    private func startMobileAdsIfAllowed() async {
        guard canRequestAds, !isMobileAdsStarted, !isMobileAdsStarting else { return }
        isMobileAdsStarting = true
        _ = await MobileAds.shared.start()
        isMobileAdsStarting = false
        isMobileAdsStarted = true
    }
}
