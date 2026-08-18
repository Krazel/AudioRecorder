import Foundation

struct TrackingConsentSignals {
    let gdprApplies: Int?
    let purposeConsents: String?
    let purposeLegitimateInterests: String?
    let vendorConsents: String?
    let vendorLegitimateInterests: String?
}

enum TrackingConsentEligibility {
    private static let googleVendorID = 755
    private static let personalizedConsentPurposes = [1, 3, 4]
    private static let operationalPurposes = [2, 7, 9, 10]

    static func isATTRequestAllowed(
        canRequestAds: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        isATTRequestAllowed(
            canRequestAds: canRequestAds,
            TrackingConsentSignals(
                gdprApplies: integerValue(
                    from: userDefaults.object(forKey: "IABTCF_gdprApplies")
                ),
                purposeConsents: userDefaults.string(forKey: "IABTCF_PurposeConsents"),
                purposeLegitimateInterests: userDefaults.string(
                    forKey: "IABTCF_PurposeLegitimateInterests"
                ),
                vendorConsents: userDefaults.string(forKey: "IABTCF_VendorConsents"),
                vendorLegitimateInterests: userDefaults.string(
                    forKey: "IABTCF_VendorLegitimateInterests"
                )
            )
        )
    }

    static func isATTRequestAllowed(
        canRequestAds: Bool,
        _ signals: TrackingConsentSignals
    ) -> Bool {
        guard canRequestAds else { return false }

        if signals.gdprApplies == 0 {
            return true
        }

        guard signals.gdprApplies == 1,
              personalizedConsentPurposes.allSatisfy({
                  bit($0, isEnabledIn: signals.purposeConsents)
              }),
              operationalPurposes.allSatisfy({ purpose in
                  bit(purpose, isEnabledIn: signals.purposeConsents)
                      || bit(purpose, isEnabledIn: signals.purposeLegitimateInterests)
              }),
              bit(googleVendorID, isEnabledIn: signals.vendorConsents),
              bit(googleVendorID, isEnabledIn: signals.vendorLegitimateInterests)
        else {
            return false
        }

        return true
    }

    private static func integerValue(from value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private static func bit(_ oneBasedPosition: Int, isEnabledIn value: String?) -> Bool {
        guard oneBasedPosition > 0,
              let value,
              value.allSatisfy({ $0 == "0" || $0 == "1" }),
              value.count >= oneBasedPosition
        else {
            return false
        }

        let index = value.index(value.startIndex, offsetBy: oneBasedPosition - 1)
        return value[index] == "1"
    }
}
