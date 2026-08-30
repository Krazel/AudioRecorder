# VoiceRecorder iOS — release data inventory

Last verified: 2026-08-30. Scope: the iOS 1.0.3 build 1 source candidate and its declared Google Mobile Ads 12.14.0, Google UMP 3.1.0, and Apple StoreKit integrations. The continuous-segmentation correction and bounded, device-local lifecycle diagnostics do not add a recipient, analytics service, account, or transmission.

This inventory is the source of truth for privacy copy and App Store Privacy answers. It describes the shipped build, not possible future features.

## Permissions and device capabilities

| Item | Used | Purpose | Transmission |
|---|---|---|---|
| Microphone | Yes, requested when recording is started | Record user-selected audio and create segments | Audio remains local unless the user explicitly shares it |
| Background audio mode | Yes | Continue an active recording when the app backgrounds | None by itself |
| Files app access / open in place | Yes | Let the user manage local recordings | None by itself |
| ATT / IDFA prompt | Yes | Ask before Google Mobile Ads can use IDFA for personalized advertising and cross-app/site measurement | IDFA and tracking are available to Google only when the user authorizes ATT |
| Location, camera, photos, contacts, Bluetooth, speech recognition, health, calendar, motion, notifications | No | Not used by shipped features | None |

## Data held on the device

- Audio recordings and their file metadata.
- User-assigned file names, favorites, and selection state needed for file management.
- Recording quality, mode, segment duration, sound threshold/tail, launch-recording preference, and selected app language.
- Local ad-removal state derived from the active StoreKit entitlement.
- Up to 200 local recording lifecycle events in Caches: timestamp, ephemeral session UUID, event/phase/mode, numeric route-reason code, and error domain/code. They exclude audio, filenames/paths, hardware-route names, accounts, and user-entered content; iOS may purge them.
- StoreKit provides verified product/transaction entitlement state; the app does not receive payment-card details.

The app has no account, developer backend, cloud account, analytics SDK, social graph, or automatic upload feature enabled in the shipped UI.

### Legacy local-only fields

`RecordingSettingsStore` still contains disabled cloud-provider, custom-endpoint, and custom-token preferences inherited from older scaffolding. `uploadAutomatically` is forced to `false` at initialization and the shipped UI does not expose these fields, so build 5 does not transmit them. Strict minimization requires removing these unused fields and clearing any legacy values in the next source build; this cleanup must not be represented as already present in build 5.

## User-initiated disclosures

- Sharing a recording opens the native iOS share sheet. The user chooses the recipient/app; the developer does not receive the file.
- Contacting support opens the user's mail client with the dedicated alias `coderappskrazel@gmail.com`. The user chooses whether to send an address, message, or attachment. Support data is retained only as needed to answer the request or meet a concrete legal obligation.
- Deleting recordings is available in the app. Uninstalling removes app-local data subject to backups managed outside the app.

## Third-party SDK data

### Google Mobile Ads / UMP

Ads are enabled for free users and removed while an eligible StoreKit subscription is active. UMP updates consent information and presents required consent/privacy options before the app requests ads.

The build 8 source candidate requests ATT only after UMP finishes and an explicit fail-closed gate confirms that the applicable European choices permit personalized advertising for Google. The gate requires positive TCF signals for device storage/access, personalized-ad profile creation and selection, the operational legal bases used by Google, and Google vendor 755. A European refusal, missing signal, malformed value, or UMP error never triggers ATT. Outside the European scope, ATT may be requested after the UMP update. `canRequestAds` is used only to decide whether Google Mobile Ads may start; it is never treated as consent to tracking. The AdMob IDFA message remains unpublished so it cannot bypass this gate. If ATT is denied or restricted when legitimately presented, the app remains fully usable and Google Mobile Ads may serve ads without sending IDFA; the app does not permit tracking without Apple's authorization.

The app target's root privacy manifest declares `NSPrivacyTracking=false` and no `NSPrivacyTrackingDomains`, because first-party app code does not provide tracking domains. Google Mobile Ads and UMP retain their vendor manifests. This does not replace or weaken ATT, `usesIdfa=true`, or the App Store privacy disclosure; it prevents the invalid `true` plus empty-domain-array combination rejected as `ITMS-91064`.

Google documents that its iOS Mobile Ads SDK may process:

- IP address, which can derive coarse location;
- device identifiers;
- advertising data;
- product interaction;
- crash data;
- performance and diagnostic data.

Purposes can include third-party advertising, analytics, app/SDK performance, and fraud prevention. The app developer may receive aggregated advertising reports, never the user's recordings through AdMob.

### Apple StoreKit

StoreKit processes optional monthly subscriptions and restoration. The app receives product metadata and verified transaction/entitlement status needed to complete purchases and remove ads. Apple handles the App Store account and payment information.

## App Store Privacy disclosure baseline

The release disclosure must include the Google SDK categories actually present: coarse location derived from IP, device ID, advertising data, product interaction, crash data, and performance/diagnostic data, with the purposes supported by Google's current disclosure. Because build 8 supports personalized advertising and measurement only when the regulatory gate and ATT both authorize it, coarse location, device ID, advertising data, product interaction, and performance data are declared as used for tracking. Crash data remains collected for diagnostics/analytics but is not declared as used for tracking.

Do not declare the user's recordings as collected by the developer: they are processed and stored only on device unless the user initiates sharing to a destination they select. Do not declare payment information as developer-collected because payment entry and processing occur in Apple's App Store flow.

Conservative linked-data baseline for the App Store questionnaire: coarse location, device ID, advertising data, product interaction, and performance data are linked to the user; Google's non-user-related crash data is not. This mapping and the conditional tracking behavior must be reconciled against the aggregated privacy report from the exact build 8 archive before submission.

## Public and private contact separation

- Public support/privacy contact: `coderappskrazel@gmail.com` only.
- App Review contact details stay privately in App Store Connect and must not be copied into this public repository.
- No public full name, home address, telephone number, personal account, or source-repository link is needed for product/support metadata.
- EU DSA trader disclosure is a separate legal requirement. If Apple requires verified trader identity/contact information for EU distribution, provide it truthfully in Apple's dedicated process; do not evade it or duplicate it into unrelated public pages.

## Required pre-release revalidation

- Generate and inspect Xcode's aggregated privacy report for the exact release archive.
- Compare App Store Privacy answers with the report and Google's then-current official data-disclosure page.
- Keep the required Privacy Policy and Support URLs; leave optional Privacy Choices, marketing, and promotional fields blank unless a concrete function requires them. Apple explicitly requested the subscription review screenshot for this submission.
- Test clean installs in an EEA review path: rejecting the European message must not show ATT; only the explicit positive TCF gate may allow the app to request ATT. Test ATT allow/deny separately, plus a non-EEA path and later withdrawal through Privacy Options. Keep the AdMob IDFA message unpublished during these tests and in production.
- Confirm the public policy names the shipped app, states that ads are enabled for free users, names Google Mobile Ads/UMP and StoreKit, and contains no hypothetical services or personal owner details.
