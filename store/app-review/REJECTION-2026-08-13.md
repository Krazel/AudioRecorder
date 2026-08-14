# App Review response preparation — 2026-08-13

Submission: `eb006012-2ca3-4b97-97d2-15564d5dc176`

Reviewed version: iOS `1.0 (5)`

Review device: iPad Air 11-inch (M3)

This file prepares the response but does not authorize or perform any App Store Connect change, build upload, In-App Purchase submission, or App Review resubmission.

## What the replacement binary changes

The next candidate is `1.0 (6)`. It keeps the existing UMP consent gate and, after UMP finishes, requests Apple's ATT authorization when its status is undetermined. Google Mobile Ads does not start and no banner is created until the ATT result is available. If the user authorizes tracking, Google may use IDFA for personalized advertising and advertising measurement. If the user denies or restricts tracking, the app remains fully usable and Google Mobile Ads serves ads without IDFA or tracking.

The six Google SDK categories remain disclosed as collected. The categories that can support personalized advertising or measurement are marked as used for tracking because that capability exists when ATT is authorized.

## App Privacy baseline for build 6

| Data type | Collected | Linked to user | Used for tracking | Purposes |
| --- | --- | --- | --- | --- |
| Coarse Location | Yes | Yes | Yes | Third-Party Advertising; Analytics |
| Device ID | Yes | Yes | Yes | Third-Party Advertising; Analytics |
| Product Interaction | Yes | Yes | Yes | Third-Party Advertising; Analytics |
| Advertising Data | Yes | Yes | Yes | Third-Party Advertising; Analytics |
| Crash Data | Yes | No | No | App Functionality; Analytics |
| Performance Data | Yes | Yes | Yes | App Functionality; Analytics; Third-Party Advertising |

Reconcile this baseline with the aggregated privacy report from the exact archived build 6 before editing App Store Connect.

## Required App Store Connect changes

1. Upload and select iOS `1.0 (6)` after explicit owner authorization.
2. Update App Privacy to the build 6 baseline above. Keep the five applicable categories marked as used for tracking and remove tracking only from non-user-related Crash Data.
3. Leave the subtitle empty in all seven localizations. The local manifest already contains no subtitle field.
4. Remove the legacy third store screenshot whose caption referenced `free`/`gratis`; keep the first two real feature screenshots in each localization. The image files are preserved locally.
5. Sync the seven localized descriptions, each with the Apple standard EULA link:
   `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
6. Upload `build-5/subscriptions-seven-levels-real.png` as the private App Review Screenshot for each of the seven subscriptions. It is a real frame from the owner's device video and clearly shows all seven products.
7. Add the subscription group and all seven subscriptions to the same review submission as version 1.0 (6).
8. Make a new physical-device recording from a clean build 6 installation. It must show launch, the UMP flow, the Apple ATT system prompt before ads, normal recording/file features, subscriptions, and legal links. The old build 5 video cannot prove the new ATT implementation.
9. Add the new recording and the response below to the private App Review information. State the review path: reinstall, launch online, complete UMP, then observe ATT before Google Mobile Ads starts.
10. Verify manual release remains selected. Resubmission and publication are separate actions.

## Response to Apple — send only after every item above is complete

Hello App Review,

Thank you for your guidance. We have addressed each item in the new iOS 1.0 (6) submission:

1. Privacy and tracking: on iOS/iPadOS 14.5 or later, the Apple App Tracking Transparency system prompt is presented during the first-launch advertising consent flow. Review path: delete and reinstall the app, launch it while connected to the internet, and complete the Google UMP privacy message. The Apple ATT prompt is then presented before Google Mobile Ads is initialized or any ad is requested. If tracking is denied or restricted, the app remains fully usable and ads may still be served without IDFA, but the app does not perform tracking without Apple authorization. We updated App Privacy to disclose the Google Mobile Ads data categories and their conditional tracking use accurately. UMP privacy choices remain available in Settings when required.

2. In-App Purchases: the subscription group and all seven optional monthly subscriptions have been included in the submission. A real App Review screenshot from the app has been provided for every subscription. Each active subscription removes ads; no core recording feature requires a subscription.

3. Metadata: all price references have been removed from the subtitle in every localization, the subtitle is now blank, and the legacy store screenshot that referenced `free`/`gratis` has been removed from the product-page screenshot set.

4. Subscription information and Terms: every localized App Description now includes the functional Apple standard Terms of Use link. Inside the app, the subscription screen displays the product title, one-month duration, localized price, automatic-renewal and cancellation information, Restore Purchases, Privacy Policy, and Terms of Use before purchase.

The attached build 6 physical-device recording starts with launching the app and demonstrates UMP, the Apple ATT system prompt, the normal recording flow, permissions, file management, sound-activated recording, the subscription flow, and the legal links. The core app functionality is consistent across regions. Users subject to regional privacy rules first see the applicable UMP regulatory message; when no UMP form is required, the flow proceeds directly to Apple's ATT prompt. In every region, Apple's ATT choice is authoritative and occurs before tracking-capable advertising starts.

No account or login is required. Recordings remain on the device unless the user explicitly shares one through the native iOS share sheet.

Thank you.

## Official references

- Apple tracking definition: https://developer.apple.com/app-store/user-privacy-and-data-use/
- Apple App Privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Google Mobile Ads data disclosure: https://developers.google.com/admob/ios/privacy/data-disclosure
- Google Mobile Ads privacy controls: https://developers.google.com/admob/ios/privacy/strategies
- Google IDFA/ATT message: https://developers.google.com/admob/ios/privacy/idfa
- Apple first subscription submission: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/
- Apple App Review Screenshot definition: https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information
