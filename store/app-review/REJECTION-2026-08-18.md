# App Review 5.1.1(iv) — GDPR and ATT sequence

## Apple finding

Apple reviewed iOS 1.0 (7) on an iPad Air 11-inch (M3) and found that the app displayed the ATT system prompt immediately after the reviewer selected `Do not consent` in the European UMP message.

## Root cause

The app used `ConsentInformation.shared.canRequestAds` as the condition for a direct `ATTrackingManager.requestTrackingAuthorization` call. UMP can allow limited or non-personalized ad requests after a refusal, so `canRequestAds` is not consent to tracking.

## Build 8 correction

- Replace the unconditional ATT request with a fail-closed eligibility gate.
- Keep the UMP update and form flow on every launch.
- Keep Mobile Ads and banner creation behind `canRequestAds`.
- In Europe, request ATT only after positive TCF signals for the required personalization purposes and Google vendor 755; rejection, missing data, malformed data, or a UMP error never triggers ATT.
- Keep the AdMob IDFA message unpublished so it cannot automatically trigger ATT after the European form.
- Keep the ATT framework and all seven localized purpose strings for the app's gated system request.
- Keep the app usable and prohibit tracking when the applicable choice or ATT does not authorize it.

## Required clean-install matrix

1. EEA, `Do not consent`: no ATT prompt in that permission flow; core app remains usable; only the UMP-permitted ad mode may run.
2. EEA, consent: the app requests ATT only when the stored TCF purposes and Google vendor signals pass the explicit eligibility gate; no ad request before that flow completes.
3. ATT deny: no IDFA or tracking; app remains usable.
4. ATT allow: IDFA/tracking may be used as disclosed.
5. Non-EEA: ATT may appear after the UMP update when the system status is not determined.
6. Privacy Options withdrawal: the more restrictive UMP choice remains authoritative even if ATT was previously authorized.
7. Reopen each path and confirm no duplicate prompt or duplicate Mobile Ads start.

## Draft response to App Review

Thank you for identifying this issue. We replaced the unconditional ATT request with an explicit, fail-closed consent gate. In the new build, selecting “Do not consent” in the European message does not show ATT and does not permit tracking. ATT is requested in Europe only when the stored TCF choices positively authorize the required personalized-advertising purposes and Google as a vendor. Missing, malformed, denied, or incomplete consent never triggers ATT. The app remains fully usable, and ad requests stay limited to the mode allowed by the user's choices. We also documented the regional review paths in App Review Notes.

Review path for the corrected build:

- EEA clean install: launch the app and select `Do not consent`; ATT is not shown.
- EEA consent path: ATT is shown only if the explicit TCF eligibility gate passes.
- Non-EEA clean install: ATT may be shown after the privacy check when applicable.

## Official references

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/user-privacy-and-data-use/
- https://developers.google.com/admob/ios/privacy/gdpr
- https://developers.google.com/admob/ios/privacy/idfa
- https://support.google.com/admob/answer/10114020
