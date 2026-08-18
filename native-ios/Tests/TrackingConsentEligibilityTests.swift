import XCTest
@testable import AudioRecorder

final class TrackingConsentEligibilityTests: XCTestCase {
    func testNonEEAAllowsATT() {
        XCTAssertTrue(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(gdprApplies: 0)
            )
        )
    }

    func testMissingRegionFailsClosed() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(gdprApplies: nil)
            )
        )
    }

    func testEuropeanRejectAllDoesNotAllowATT() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(gdprApplies: 1)
            )
        )
    }

    func testAdsNotRequestableFailsClosedEvenWithPositiveSignals() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: false,
                signals(
                    gdprApplies: 1,
                    consentPurposes: [1, 3, 4],
                    legitimateInterestPurposes: [2, 7, 9, 10],
                    googleVendorConsent: true,
                    googleVendorLegitimateInterest: true
                )
            )
        )
    }

    func testEuropeanFullConsentAllowsATT() {
        XCTAssertTrue(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(
                    gdprApplies: 1,
                    consentPurposes: [1, 3, 4],
                    legitimateInterestPurposes: [2, 7, 9, 10],
                    googleVendorConsent: true,
                    googleVendorLegitimateInterest: true
                )
            )
        )
    }

    func testMissingPersonalizationPurposeFailsClosed() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(
                    gdprApplies: 1,
                    consentPurposes: [1, 3],
                    legitimateInterestPurposes: [2, 7, 9, 10],
                    googleVendorConsent: true,
                    googleVendorLegitimateInterest: true
                )
            )
        )
    }

    func testMissingGoogleVendorConsentFailsClosed() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(
                    gdprApplies: 1,
                    consentPurposes: [1, 3, 4],
                    legitimateInterestPurposes: [2, 7, 9, 10],
                    googleVendorConsent: false,
                    googleVendorLegitimateInterest: true
                )
            )
        )
    }

    func testMissingOperationalBasisFailsClosed() {
        XCTAssertFalse(
            TrackingConsentEligibility.isATTRequestAllowed(
                canRequestAds: true,
                signals(
                    gdprApplies: 1,
                    consentPurposes: [1, 3, 4],
                    legitimateInterestPurposes: [2, 7, 9],
                    googleVendorConsent: true,
                    googleVendorLegitimateInterest: true
                )
            )
        )
    }

    private func signals(
        gdprApplies: Int?,
        consentPurposes: Set<Int> = [],
        legitimateInterestPurposes: Set<Int> = [],
        googleVendorConsent: Bool = false,
        googleVendorLegitimateInterest: Bool = false
    ) -> TrackingConsentSignals {
        TrackingConsentSignals(
            gdprApplies: gdprApplies,
            purposeConsents: bitString(length: 10, enabled: consentPurposes),
            purposeLegitimateInterests: bitString(
                length: 10,
                enabled: legitimateInterestPurposes
            ),
            vendorConsents: bitString(
                length: 755,
                enabled: googleVendorConsent ? [755] : []
            ),
            vendorLegitimateInterests: bitString(
                length: 755,
                enabled: googleVendorLegitimateInterest ? [755] : []
            )
        )
    }

    private func bitString(length: Int, enabled: Set<Int>) -> String {
        (1...length).map { enabled.contains($0) ? "1" : "0" }.joined()
    }
}
