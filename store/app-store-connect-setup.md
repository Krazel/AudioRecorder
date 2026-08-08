# App Store Connect Setup — Voice Recorder Pro - Audio K

App: `Voice Recorder Pro - Audio K`

Bundle ID: `com.dmkr.audio.B2X6D3A9J9`

App Store Connect App ID: `6772278149`

Version: `1.0`

Subscription group: `Voice Recorder Pro - Audio K Support`

Recorded group ID: `22136463`

This file describes the intended release configuration. It deliberately does **not** claim a current App Store Connect status: prices, availability, agreements, screenshots, localizations, and review state must be checked again in the signed-in account immediately before submission.

## Local source of truth

- Store metadata and product definitions: `store/store-manifest.json`
- Privacy policy source: `docs/PRIVACY.md`
- Standalone GitHub Pages version: `docs/privacy.html`
- Provisional privacy URL for the app and App Store Connect:
  `https://github.com/Krazel/AudioRecorder/blob/main/docs/PRIVACY.md`
- Optional GitHub Pages URL, only after Pages is enabled and the address has been tested:
  `https://krazel.github.io/AudioRecorder/privacy.html`
- Support URL: `https://github.com/Krazel/AudioRecorder/issues`
- Marketing URL: `https://github.com/Krazel/AudioRecorder`
- Apple standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

The privacy URL will not be public until the new policy is committed and pushed to the public repository. Publishing or submitting requires the owner's express approval.

## AdMob/UMP state prepared locally

- The iOS integration requests UMP consent information on every launch and gates Mobile Ads plus banner loading behind `canRequestAds`.
- The privacy-options action is exposed only when UMP reports it as required.
- Local and unsigned builds retain Google's demo App ID and banner ID. Signed App Store archives require separate production values and reject the demo publisher.
- Google Mobile Ads is pinned to `12.14.0` and UMP to `3.1.0` until a major-version migration can be compiled and regression-tested on macOS.
- `Info.plist` contains the 50 SKAdNetwork identifiers from Google's official iOS quick-start example checked on 2026-08-08.
- No ATT/IDFA prompt, test-device hash, forced geography, consent reset, tracking domain, or invented console value is embedded in the release configuration.

After AdMob account verification, the only required advertising values are:

1. iOS AdMob App ID for bundle `com.dmkr.audio.B2X6D3A9J9` (`ca-app-pub-…~…`).
2. Banner ad unit ID for that app (`ca-app-pub-…/…`).

The owner must also create, associate, translate, and publish the applicable messages in AdMob **Privacy & messaging**. UMP downloads those messages from Google; there is no local substitute.

## Subscription model for version 1.0

All six products are optional monthly support levels. They provide the **same service**: ads are removed while the selected subscription remains active. The amount changes only the voluntary level of support.

Because the service is identical, configure all six products at the **same subscription level** within the group. Do not describe higher prices as unlocking additional features.

| Product ID | Recorded ASC ID | Reference name | Duration | Target base price | Spanish display name | English display name |
| --- | --- | --- | --- | ---: | --- | --- |
| `com.dmkr.audio.support.monthly.099` | `6777118434` | `Audio K Support Monthly 0.99` | 1 month | 0.99 | Apoyo Básico mensual | Basic Support Monthly |
| `com.dmkr.audio.support.monthly.299` | `6777118297` | `Audio K Support Monthly 3` | 1 month | 3.00 | Apoyo Amigo mensual | Friend Support Monthly |
| `com.dmkr.audio.support.monthly.499` | `6777118235` | `Audio K Support Monthly 5` | 1 month | 5.00 | Apoyo Especial mensual | Special Support Monthly |
| `com.dmkr.audio.support.monthly.999` | `6777163959` | `Audio K Support Monthly 10` | 1 month | 10.00 | Apoyo Generoso mensual | Generous Support Monthly |
| `com.dmkr.audio.support.monthly.1499` | `6777165706` | `Audio K Support Monthly 15` | 1 month | 15.00 | Gran Apoyo mensual | Great Support Monthly |
| `com.dmkr.audio.support.monthly.2999` | `6777165727` | `Audio K Support Monthly 30` | 1 month | 30.00 | Patrocinador mensual | Sponsor Support Monthly |

The manifest contains subscription metadata for `es-ES`, `en-US`, `fr-FR`, `de-DE`, `it`, `pt-PT`, and `ca`. Every localized description states that the contribution is voluntary and removes ads only while active.

### Products not included in version 1.0

These previously created products are intentionally absent from the local manifest and must not be attached to the 1.0 submission:

- `com.dmkr.audio.support.monthly.4999`
- `com.dmkr.audio.support.monthly.9999`
- `com.dmkr.audio.support.monthly.29999`

Do not delete product identifiers merely to clean the account: deletion can make identifiers unavailable for reuse. Verify in App Store Connect that these products are not cleared for sale and are not added to the review submission.

## Subscription checklist

- [ ] Confirm that the group and all six intended products exist with the recorded identifiers.
- [ ] Put all six products at the same subscription level because their service is equivalent.
- [ ] Confirm one-month duration and the intended local price schedule for each product.
- [ ] Confirm availability and cleared-for-sale status only for the six intended products.
- [ ] Confirm all seven localizations against `store-manifest.json`.
- [ ] Upload and inspect a current review screenshot for every product.
- [ ] Confirm the review note accurately says that the selected monthly support level removes ads while active.
- [ ] Confirm the app lists only these six identifiers and handles purchase, restore, renewal, expiration, revocation, and switching between equal-service products.
- [ ] Test every product in StoreKit testing or the App Store sandbox on a real device.
- [ ] Attach the intended subscriptions to version 1.0. Apple's first subscription must be submitted with a new app version.
- [ ] Ensure the 50, 100, and 300 products are not for sale and are not attached to review.

## Required subscription disclosure in the app

Before the purchase action, the user must be able to understand:

- that this is optional support;
- the selected level and localized price;
- that the duration is one month;
- that the subscription renews automatically until cancelled;
- that ads remain removed only while the subscription is active;
- how to restore purchases and how to manage or cancel the subscription;
- the Privacy Policy and Terms of Use links.

Suggested neutral copy:

> Optional monthly support. Every level removes ads while active. Payment is charged to your Apple account. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it in your Apple account settings.

Use Apple's displayed localized product price rather than hard-coding a currency amount in the purchase screen.

## Privacy and legal checklist

- [ ] Commit and publish `docs/PRIVACY.md`, then open the public URL in a signed-out browser.
- [ ] Add the verified Privacy Policy URL to App Store Connect for every relevant localization.
- [ ] Keep an easily accessible Privacy Policy link inside the app.
- [ ] Link the Apple standard EULA in the subscription screen and App Store description, unless a custom EULA is adopted later.
- [ ] Complete App Privacy answers for the app **and its third-party SDKs**.
- [x] Bundle `PrivacyInfo.xcprivacy` with reasons `CA92.1` (app-only preferences) and `C617.1` (metadata for files in the app container).
- [ ] Generate or inspect the archived app's privacy report/manifest and reconcile it with the App Store privacy answers.
- [ ] Review the current Google Mobile Ads SDK disclosure. Depending on configuration, it may process IP/general location, device identifiers, advertising data, product interactions, crash data, performance data, and diagnostics.
- [x] Integrate UMP locally so no ad request occurs before `canRequestAds`, with privacy options exposed when required.
- [ ] In AdMob, create/associate/translate/publish the applicable regional messages, then test the real downloaded CMP.
- [ ] Ensure tracking/IDFA answers and any App Tracking Transparency prompt match actual SDK behavior.
- [ ] Confirm the production AdMob app and ad-unit identifiers; do not submit a monetized release using Google's test identifiers.
- [ ] Complete age rating, content rights, advertising identifier questions, support contact, and review contact.
- [ ] In App Review notes, describe every mechanism that removes ads, including any retained manual code mechanism; do not present hidden functionality misleadingly.
- [ ] Confirm Paid Apps Agreement, banking, and tax status before attempting to sell subscriptions.

The privacy policy states the verified product design: recordings stay on the device, sharing is initiated by the user, no account is required, Apple processes StoreKit payments, and Google Mobile Ads may process advertising and technical data. If implementation or SDK configuration changes, update both the policy and App Store privacy answers before release.

Official references:

- Apple App Privacy: `https://developer.apple.com/app-store/app-privacy-details/`
- Apple App Review Guidelines: `https://developer.apple.com/app-store/review/guidelines/`
- Apple subscriptions: `https://developer.apple.com/app-store/subscriptions/`
- Google Mobile Ads iOS data disclosure: `https://developers.google.com/admob/ios/privacy/data-disclosure`

## Version 1.0 submission checklist

- [ ] Categories and age rating completed.
- [ ] Privacy, content rights, and advertising declarations completed.
- [ ] Paid agreement, banking, and tax confirmed active.
- [ ] Final signed build uploaded and selected for version 1.0.
- [ ] Required screenshots and localized metadata reviewed in App Store Connect.
- [ ] Six intended subscriptions attached to the version and added to review.
- [ ] App Review contact information, demo instructions if needed, and accurate review notes completed.
- [ ] Final device smoke test completed using the exact release build.
- [ ] Owner gives express approval before pressing **Submit for Review**.

### RC-001 device validation (exact archived candidate)

- [ ] Fresh install and upgrade launch successfully on the oldest supported iOS 16 device and a current iOS device.
- [ ] The selector immediately switches the complete visible UI among ca/de/en/es/fr/it/pt and the choice survives relaunch.
- [ ] Continuous mode records, displays level/time, rotates a short test segment, saves, plays, renames, favorites, shares, and deletes it.
- [ ] Sound-activated mode remains responsive while analyzing and writing; verify the main-thread checker and inspect for dropped-buffer or queue-backlog symptoms.
- [ ] Sound threshold and tail settings behave at 0, 0.5, 1, 3, and 5 seconds; silent empty segments are not kept.
- [ ] Recording survives screen lock and at least 15 minutes in background; segment completion and recovery are correct after foregrounding.
- [ ] Call, Siri, alarm, route change, Bluetooth connect/disconnect, and media-services recovery preserve completed audio and resume or stop truthfully.
- [ ] Low-storage or write-failure behavior stops without claiming to keep recording and preserves any valid completed audio.
- [ ] Playback, recording, sharing, and deletion are checked with VoiceOver and large Dynamic Type for blocking defects.
- [ ] Sandbox StoreKit loads exactly six tiers, shows localized App Store prices, purchases one tier, restores it, and removes ads only while entitlement is active.
- [ ] Sandbox upgrade/downgrade/cancel/expire/revoke flows keep entitlement state correct and do not disable a valid retained manual unlock.
- [ ] Privacy Policy, Terms of Use, subscription management, and support email links open on a real device.
- [ ] Battery use and thermal behavior are observed during a 30-minute continuous recording and a 30-minute sound-activated recording.

### Actions requiring owner approval, credentials, or external systems

- [ ] Wait for the new AdMob account verification; then register/confirm the iOS app, create/confirm its banner unit, and provide the two production IDs. Do not ship Google's demo IDs.
- [ ] Configure, translate, associate, and publish the applicable AdMob privacy messages; test consent withdrawal and reconcile the final non-ATT configuration with App Privacy answers.
- [ ] Run the unsigned macOS CI build for 1.0 with `publish_release=false`; inspect the generated app bundle and IPA before any publication.
- [ ] Run the signed archive/export workflow with `upload_to_app_store=false`; validate the archive and aggregated privacy report before any upload.
- [ ] Verify the six intended subscriptions in App Store Connect; keep the 50/100/300 products unavailable and unattached to version 1.0.
- [ ] Confirm agreements, tax, banking, age rating, categories, App Privacy, review contact, localized metadata, and public privacy URL while signed out.
- [ ] Describe the retained hidden manual unlock mechanism accurately in App Review notes.
- [ ] Obtain separate express owner approval before uploading a build, publishing an IPA release, attaching items to review, or submitting for review.

## Existing screenshot references

Recorded iPhone 6.7 screenshot set: `APP_IPHONE_67` (`4f18f90b-d3cc-4d73-ad6d-ecb70b562a3a`). Reconfirm these identifiers in App Store Connect before relying on them.

1. `store/app-store/es-ES/iphone-67-real/01-preparado-real.png`
2. `store/app-store/es-ES/iphone-67-real/02-grabando-real.png`
3. `store/app-store/es-ES/iphone-67-real/03-archivos-real.png`

The recorded dimensions are `1290x2796`.

## API and build notes

App Store Connect metadata tooling expects:

```powershell
$env:ASC_KEY_ID="..."
$env:ASC_ISSUER_ID="..."
$env:ASC_PRIVATE_KEY_PATH="C:\ruta\AuthKey_XXXX.p8"
```

Validation and upload commands documented by the project:

```powershell
node tools\store-publishing\scripts\appstoreconnect-check.mjs Audio\store\store-manifest.json
node tools\store-publishing\scripts\appstoreconnect-metadata.mjs Audio\store\store-manifest.json --upload
```

The upload workflow is `.github/workflows/upload-ios-appstore.yml` and expects these repository secrets:

```text
APPLE_TEAM_ID
ASC_KEY_ID
ASC_ISSUER_ID
ASC_PRIVATE_KEY_BASE64
ADMOB_IOS_APP_ID
ADMOB_IOS_BANNER_UNIT_ID
```

The signed workflow also requires an explicit unused positive `build_number` for version 1.0. Check the highest build already present in App Store Connect before running it. `validate_with_app_store` and `upload_to_app_store` both default to `false`; enabling either is an external action requiring contemporaneous owner authorization.

A successful no-upload run retains:

- the exported IPA;
- the signed `.xcarchive`, including its dSYM;
- checks for bundle/version/build identity, production AdMob IDs, signature, provisioning profile, privacy manifest, asset catalog, seven localizations, dSYM, and the archive's `UIDeviceFamily`.

The final privacy report still has to be generated or inspected with Xcode Organizer. ATT, export-compliance classification, and iPhone-only versus universal device family remain explicit owner decisions.

Do not put private keys or secret values in this document or in the manifest.
