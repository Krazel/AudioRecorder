# VoiceRecorder iOS 1.0.8 (1) — App Review preflight

Prepared: 2026-08-31

This document gates the exact production archive. It does not authorize a
different marketing version, build number, ad configuration, or automatic
public release.

## Candidate identity

- App Apple ID: `6772278149`
- Bundle: `com.dmkr.audio.B2X6D3A9J9`
- Version/build: `1.0.8 (1)`
- Platform: iPhone only, portrait, minimum iOS 16
- Localizations: `ca`, `de-DE`, `en-US`, `es-ES`, `fr-FR`, `it`, `pt-PT`
- Release: `MANUAL`
- The submission contains only this app version. The seven existing
  subscriptions are not resubmitted when they remain `APPROVED` and unchanged.

## Source and privacy gates

- No `AVAudioRecorder` or `record(forDuration:)`; segment rotation keeps one
  continuous `AVAudioEngine` and changes only the destination file.
- Mode selection is disabled while recording.
- Recording liveness uses real input-buffer heartbeats and a dispatch watchdog;
  retries stop only after an explicit Stop.
- Siri/audio interruption recovery is attempted whenever iOS permits execution.
  An accepted phone call may suspend a general recording app; the app preserves
  intent and retries on the next execution opportunity.
- Active recording files use `completeUntilFirstUserAuthentication`, and local
  unindexed files are recovered before automatic restart.
- No Internal QA section, diagnostic JSON/export, cloud uploader, server
  endpoint, upload token, account, analytics SDK, or automatic transmission.
- Microphone is the only feature permission besides conditional ATT.

## AdMob, UMP, and ATT gates

- Archive contains exactly app ID `ca-app-pub-3425091654264901~2340753104`
  and banner ID `ca-app-pub-3425091654264901/5497133550`.
- `app-ads.txt`, landing, privacy, and support return HTTP 200.
- One European message is active; the AdMob IDFA explanatory message is
  unpublished; Policy Center has no ad-serving issue.
- No ad request occurs before UMP `canRequestAds`.
- European refusal, incomplete/malformed consent, or UMP failure cannot trigger
  ATT. Denying ATT leaves the recorder usable without IDFA tracking.
- The archive privacy manifests pass Apple's structure rules. The app manifest
  uses `NSPrivacyTracking=false` with no tracking-domain array, avoiding the
  previous `ITMS-91064` invalid combination.
- App Store Connect uses `usesIdfa=true`; App Privacy must match the exact
  archive privacy report and Google's current SDK disclosure.

## StoreKit and metadata gates

- Exactly seven approved monthly subscription products are present.
- Every level removes ads while active; core recording stays free.
- Price and duration come from StoreKit. Renewal, cancellation, restoration,
  management, Privacy Policy, and Terms of Use appear before purchase.
- Review Notes state that USD 44.99 monthly for `Audio K Support Monthly 50 v2`
  is intentional.
- Two actual-app iPhone screenshots remain attached to every localization.
- Marketing: `https://krazel.github.io/audio-recorder/`
- Support: `https://krazel.github.io/audio-recorder/support/`
- Privacy: `https://krazel.github.io/audio-recorder/privacy/`
- Terms: Apple's standard EULA.
- The private App Review phone remains in international `+` format.
- `What's New` is populated in all seven languages.

## CI and submission sequence

1. `manage-ios-1.0.8-release.yml / verify-unused`
2. `verify-ios-recording-stability.yml`
3. `upload-ios-appstore.yml` with production AdMob, validation, and upload
4. `manage-ios-1.0.8-release.yml / finalize-production`
5. `manage-ios-1.0.8-release.yml / prepare`
6. Re-run exact status/preflight and confirm manual release
7. `manage-ios-1.0.8-release.yml / submit`
8. Confirm `WAITING_FOR_REVIEW` or `IN_REVIEW`, selected build `1.0.8 (1)`, and
   release `MANUAL`

The final step sends the update to Apple for approval but never publishes it.
