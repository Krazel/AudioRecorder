# VoiceRecorder iOS — visual approval manifest

Last verified: 2026-08-13.

This file is the canonical index of complete visual references that govern the real iOS app. It does not grant approval by itself: an entry is `CURRENT` only when the owner explicitly approved that exact visual. Proposals stay under `docs/icon-proposals/` and store exports stay under `store/`; neither becomes a master merely by existing or being used in a build.

When a replacement is approved, add the new file without deleting the previous one, mark the new entry `CURRENT`, and mark the previous entry `SUPERSEDED` with the replacement ID. Update SHA-256 whenever the bytes change; a changed hash is a different visual and requires a new approval record.

## Approved masters

| ID | Surface / state | Status | Approved reference | Device or canvas | Orientation | Language | Approval date | SHA-256 | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `IOS-ICON-BLACK-001` | iOS app icon, black background | `CURRENT` | `design/approved/ios/app-icon/ribbon-dot-black-1024.png` | 1024 × 1024 px | Square | No text | 2026-08-09 | `c2ea4e285d00c52a2e98ef1968ba2a371ffe69f11014d12fe3a33bbd094b1c2f` | Exact 1024 px production export of owner-approved proposal 3. Approval recorded in `DECISIONS.md` D-020. |

## Implemented visual not yet promoted to an approved master

| ID | Surface / state | Status | Current implementation | Device or canvas | Orientation | Language | Date introduced | SHA-256 | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `IOS-ICON-WHITE-TRIAL-001` | iOS app icon, white background | `PROVISIONAL_IN_BUILD` | `native-ios/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | 1024 × 1024 px | Square | No text | 2026-08-09 | `8d8439197d1ee6f8dfc8438f84df8240791a8e79eacec526574c157b146e34d2` | Owner authorized a TestFlight trial, not a final replacement approval. This is the icon embedded in candidate build 1.0 (5). Its proposal source remains `docs/icon-proposals/05-ribbon-dot-white-1024.png`. |

## Screen/state coverage audit

The existing application predates the canonical-master rule. No explicit owner approval of a complete full-screen image is recorded for the following implemented states. These files are runtime evidence only and must not be presented as approved visual masters. A future redesign or final visual replacement requires an approved complete image per state before implementation.

| Surface / state | Approval status | Runtime evidence | Device or canvas | Orientation | Language | Evidence date | SHA-256 |
|---|---|---|---|---|---|---|---|
| Record — ready | `NO_APPROVED_MASTER_RECORDED` | `store/app-store/es-ES/iphone-67-real/01-preparado-real.png` | 1290 × 2796 px, iPhone 6.7-inch store capture | Portrait | Spanish (`es-ES`) | 2026-05-22 | `c5bc49d3ea3bfa6528bc8225c9c8da2ff759ca76700ab9f2cfe31baac3ecd439` |
| Record — recording | `NO_APPROVED_MASTER_RECORDED` | `store/app-store/es-ES/iphone-67-real/02-grabando-real.png` | 1290 × 2796 px, iPhone 6.7-inch store capture | Portrait | Spanish (`es-ES`) | 2026-05-22 | `6e1f36ae5a459984a42eef865aa63c559b2eccfaae28004d7c9df1491a05ba60` |
| Files — list | `NO_APPROVED_MASTER_RECORDED` | `store/app-store/es-ES/iphone-67-real/03-archivos-real.png` | 1290 × 2796 px, iPhone 6.7-inch store capture | Portrait | Spanish (`es-ES`) | 2026-05-22 | `ce824d9062c33b4dca1dc578b0dbe89ae150f5dafcc223d77bd547b45fd656c6` |
| Settings — base | `NO_APPROVED_MASTER_RECORDED` | — | iPhone | Portrait | Seven supported localizations | — | — |
| Settings — support/subscriptions expanded | `NO_APPROVED_MASTER_RECORDED` | `store/app-review/build-5/subscriptions-seven-levels-real.png` | 1290 × 2796 px, real frame from build 5 device recording | Portrait | Spanish (`es-ES`) | 2026-08-10 | `34dd93ff0b548f92d9cf3ec0b6237704e8072854dd86e032ab7766fd78e6d532` |
| Google UMP consent / privacy options | `SDK_OWNED_UI` | — | iPhone | Portrait | Region/configuration dependent | — | — |

## Store-image provenance rule

- Store artwork uses the `CURRENT` masters above only as art direction.
- The final base screenshot must come from the real release-candidate build at an accepted App Store device size.
- Each store-ready export must record the originating build, runtime capture path, governing approval ID, locale, dimensions, date, and SHA-256 here or in a directly linked child manifest.
- Existing files under `store/app-store/` are legacy exports/runtime evidence unless a later row explicitly promotes them. They are not approved masters by implication.
- `store/app-review/build-5/subscriptions-seven-levels-real.png` is private App Review evidence extracted from the owner's real device recording at 36.9 seconds. It is not synthetic artwork, a public store screenshot, or an approved visual master.
- Android assets and all files under `artifact/` are outside this manifest and remain untouched.
