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
  `https://krazel.github.io/audio-recorder/privacy/`
- Support URL: `https://krazel.github.io/audio-recorder/support/`
- Marketing URL: leave blank; it is optional and the product does not need to expose a repository or owner account.
- Promotional text: leave blank unless a future release has a concrete, current message that is not already covered by its description.
- Subtitle and keywords: leave blank under the owner's strict-minimization decision; they are optional and are not needed to explain or review the product.
- Apple standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

The public privacy URL above is the only privacy-policy URL for this release. Publishing changes or submitting requires the owner's express approval.

## AdMob/UMP state prepared locally

- The iOS integration requests UMP consent information on every launch and gates Mobile Ads plus banner loading behind `canRequestAds`.
- The privacy-options action is exposed only when UMP reports it as required.
- The next public candidate completes the UMP flow, requests Apple's ATT permission when its status is undetermined, and waits for the result before Google Mobile Ads starts. Authorized users may receive personalized advertising and measurement using IDFA; denied/restricted users remain fully functional and receive ads without IDFA or tracking.
- Local/unsigned builds and the authorized internal TestFlight beta may use Google's exact demo App ID and banner ID. The beta workflow exports that configuration as `TestFlight Internal Only`, so Apple prevents external testing or customer distribution from that build.
- Any public candidate requires a newly generated archive with separate production values; the production workflow path rejects the demo publisher.
- Google Mobile Ads is pinned to `12.14.0` and UMP to `3.1.0` until a major-version migration can be compiled and regression-tested on macOS.
- `Info.plist` contains the 50 SKAdNetwork identifiers from Google's official iOS quick-start example checked on 2026-08-08.
- No test-device hash, forced geography, consent reset, invented tracking domain, or invented console value is embedded in the release configuration. `NSUserTrackingUsageDescription` and the ATT framework are present and localized in all seven languages. App Store Privacy must disclose Google SDK collection and the categories used for tracking when ATT is authorized.

After AdMob account verification, the only required advertising values are:

1. iOS AdMob App ID for bundle `com.dmkr.audio.B2X6D3A9J9` (`ca-app-pub-…~…`).
2. Banner ad unit ID for that app (`ca-app-pub-…/…`).

The owner must also create, associate, translate, and publish the applicable messages in AdMob **Privacy & messaging**. UMP downloads those messages from Google; there is no local substitute.

## Subscription model for version 1.0

All seven products are optional monthly support levels. They provide the **same service**: ads are removed while the selected subscription remains active. The amount changes only the voluntary level of support.

Because the service is identical, configure all seven products at the **same subscription level** within the group. Do not describe higher prices as unlocking additional features.

| Product ID | Recorded ASC ID | Reference name | Duration | Target base price | Spanish display name | English display name |
| --- | --- | --- | --- | ---: | --- | --- |
| `com.dmkr.audio.support.monthly.099` | `6777118434` | `Audio K Support Monthly 0.99` | 1 month | 0.99 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.299` | `6777118297` | `Audio K Support Monthly 3` | 1 month | 3.00 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.499` | `6777118235` | `Audio K Support Monthly 5` | 1 month | 5.00 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.999` | `6777163959` | `Audio K Support Monthly 10` | 1 month | 10.00 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.1499` | `6777165706` | `Audio K Support Monthly 15` | 1 month | 15.00 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.2999` | `6777165727` | `Audio K Support Monthly 30` | 1 month | 30.00 | Sin anuncios | No ads |
| `com.dmkr.audio.support.monthly.50` | `6799674367` | `Audio K Support Monthly 50 v2` | 1 month | 49.99 | Sin anuncios | No ads |

The manifest contains subscription metadata for `es-ES`, `en-US`, `fr-FR`, `de-DE`, `it`, `pt-PT`, and `ca`. Every localized description states that the contribution is voluntary and removes ads only while active.

## Subscription checklist

- [ ] Confirm that the group and all seven intended products exist with the recorded identifiers.
- [ ] Put all seven products at the same subscription level because their service is equivalent.
- [ ] Confirm one-month duration and the intended local price schedule for each product.
- [ ] Confirm availability and cleared-for-sale status for the seven intended products.
- [ ] Confirm all seven localizations against `store-manifest.json`.
- [x] App Review requested a subscription screenshot on 2026-08-13. Use only the real build 5 frame at `store/app-review/build-5/subscriptions-seven-levels-real.png`; it shows all seven products and is private review evidence, not public store artwork.
- [x] Upload that real review screenshot to each of the seven subscriptions before adding them to review. Review notes remain concise and explain that every product is a monthly subscription which removes ads while active.
- [ ] Confirm the app lists only these seven identifiers and handles purchase, restore, renewal, expiration, revocation, and switching between equal-service products.
- [ ] Test every product in StoreKit testing or the App Store sandbox on a real device.
- [x] Attach the intended subscriptions to version 1.0. Apple's first subscription is submitted with the new app version.

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
- [x] In AdMob, create, associate, translate, and publish the European regulations message for the seven supported languages.
- [x] The build 6 source candidate retains UMP and requests ATT after UMP but before starting Google Mobile Ads. The purpose string is present in `Info.plist` and all seven `InfoPlist.strings` localizations.
- [ ] Optional but recommended: in AdMob Privacy & messaging, create, associate, translate, and publish the IDFA explainer for this app. The app directly requests ATT after UMP with a status guard, so the Apple system prompt does not depend on this optional AdMob explainer.
- [ ] Reconcile App Store Privacy against the build 6 archive: disclose all six Google categories; mark coarse location, device ID, product interaction, advertising data, and performance data as used for tracking, but not non-user-related crash data.
- [ ] Confirm the production AdMob app and ad-unit identifiers; never use the internal demo build for external TestFlight or a public submission.
- [x] Complete age rating, content rights, support contact, and review contact. ATT/IDFA is intentionally enabled only after the system authorization flow.
- [x] StoreKit subscriptions are the only mechanism that removes ads in build 6; there is no hidden code mechanism to disclose.
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
- [x] Required screenshots and localized metadata reviewed in App Store Connect.
- [x] Seven intended subscriptions and their group attached to version 1.0 (6) and added to review with the real screenshot requested by Apple.
- [x] App Review contact information and accurate review notes completed; no login or demo credentials are required.
- [x] For the ATT/AdMob release path, verify `appStoreVersions.usesIdfa=true` and confirm the persisted value before submission. Leaving it unset caused the 2026-08-15 `INVALID_BINARY`; the deprecated detailed `idfaDeclarations` resource and its old purpose screen are no longer part of the current App Store Connect flow.
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
- [ ] Sandbox StoreKit loads exactly seven tiers, shows localized App Store prices, purchases one tier, restores it, and removes ads only while entitlement is active.
- [ ] Sandbox upgrade/downgrade/cancel/expire/revoke flows keep entitlement state correct and do not disable a valid retained manual unlock.
- [ ] Privacy Policy, Terms of Use, subscription management, and support email links open on a real device.
- [ ] Battery use and thermal behavior are observed during a 30-minute continuous recording and a 30-minute sound-activated recording.

### Actions requiring owner approval, credentials, or external systems

- [ ] The internal beta may use the exact Google demo pair. Wait for AdMob verification before generating any public candidate; then register/confirm the iOS app, create/confirm its banner unit, and provide the two production IDs.
- [ ] Configure, translate, associate, and publish the applicable AdMob privacy and IDFA messages; test UMP withdrawal plus ATT authorize/deny outcomes and reconcile the archive with App Privacy answers.
- [ ] Run the unsigned macOS CI build for 1.0 with `publish_release=false`; inspect the generated app bundle and IPA before any publication.
- [ ] Run the signed archive/export workflow with `upload_to_app_store=false`; validate the archive and aggregated privacy report before any upload.
- [ ] Verify the seven intended subscriptions in App Store Connect; the deleted legacy 50/100/300 identifiers must remain absent.
- [x] Confirm agreements, tax, banking, age rating, categories, App Privacy, review contact, localized metadata, and public privacy URL while signed out.
- [x] Confirm that the public candidate contains no hidden manual unlock mechanism; StoreKit is the only path that removes ads.
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

The upload workflow is `.github/workflows/upload-ios-appstore.yml`. Every signed build expects these Apple secrets in the environment-scoped `app-store-production` configuration:

```text
APPLE_TEAM_ID
ASC_KEY_ID
ASC_ISSUER_ID
ASC_PRIVATE_KEY_BASE64
IOS_DISTRIBUTION_P12_BASE64
IOS_DISTRIBUTION_P12_PASSWORD
IOS_APP_STORE_PROFILE_BASE64
ADMOB_IOS_APP_ID
ADMOB_IOS_BANNER_UNIT_ID
```

The two AdMob secrets are required only for `ad_configuration=production`. The internal beta uses Google's fixed official demo pair and must use `ad_configuration=test`, which writes `testFlightInternalTestingOnly=true` into the export options. The first four Apple secrets authenticate App Store Connect; the P12, its password, and the provisioning profile provide the separate Apple Distribution signing identity. All seven belong in the protected GitHub environment `app-store-production`; their values are never stored in this repository. The workflow decodes them only under `$RUNNER_TEMP`, validates that the profile matches the team, bundle, certificate, and expiration, then removes the temporary keychain and profile with an `always()` cleanup step.

The signed workflow also requires an explicit unused positive `build_number` for version 1.0. The live App Store Connect check found no prior builds, so build `1` is available for this beta. `validate_with_app_store` and `upload_to_app_store` both default to `false`; enabling either is an external action requiring contemporaneous owner authorization. Uploading a test-ID build additionally requires `confirm_internal_testflight_only=true`.

A successful no-upload run retains:

- the exported IPA;
- the signed `.xcarchive`, including its dSYM;
- checks for bundle/version/build identity, the selected AdMob IDs, signature, distribution provisioning identity/entitlements, privacy manifest, asset catalog, seven localizations, dSYM, and the archive's `UIDeviceFamily`.

The final privacy report still has to be generated or inspected with Xcode Organizer. VoiceRecorder 1.0 is explicitly iPhone-only (`TARGETED_DEVICE_FAMILY=1`) and portrait. ATT is now an explicit build 6 decision; export-compliance classification remains unchanged unless the implementation changes.

Do not put private keys or secret values in this document or in the manifest.
