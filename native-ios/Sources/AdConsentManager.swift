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
            await startMobileAdsIfAllowed()
            return
        }

        refreshConsentState()

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // A form error must not trigger a new tracking request. UMP may still retain
            // an earlier ad-serving choice, so canRequestAds remains the ad-only gate.
            refreshConsentState()
            await startMobileAdsIfAllowed()
            return
        }

        refreshConsentState()
        await requestTrackingAuthorizationIfEligible()
        await startMobileAdsIfAllowed()
    }

    func presentPrivacyOptions() async {
        guard isPrivacyOptionsRequired, !isPresentingPrivacyOptions else { return }
        isPresentingPrivacyOptions = true
        defer { isPresentingPrivacyOptions = false }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            refreshConsentState()
            // Do not follow a privacy-choice change with ATT in the same flow.
            // A later launch can request ATT if the stored choices are eligible.
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

    private func requestTrackingAuthorizationIfEligible() async {
        guard !didRequestTrackingAuthorization,
              TrackingConsentEligibility.isATTRequestAllowed(
                  canRequestAds: canRequestAds
              )
        else { return }

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
