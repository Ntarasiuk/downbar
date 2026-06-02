# Downbar — Sprint 2: Launch v1.0 + start v1.1

**Sprint goal:** Get Downbar **live on the Mac App Store**, then land the highest-leverage
post-launch improvements. Sprint 1 finished the v1.0 code (build + 41 tests green); this
sprint is about *shipping it* and starting v1.1.

**Duration:** ~1 week of work + App Review wait (~1–3 days)
**Definition of done:** app approved and live at $2.99; pre-submission hardening complete;
uptime-history v1.1 feature started behind the line.

> Status legend: ☐ todo · ◐ in progress · ☑ done
> 🤖 = I can do it · 🍎 = needs your Apple account/GUI · 🤝 = shared (I prep, you finish)

---

## ✅ Sprint 2 result (2026-06-02) — build clean, `swift test` 64 tests (7 live-canary skipped), 0 failures

**Done (verified):**
- ☑ **R1** Archive path verified — xcodegen generates + `xcodebuild` builds the app target. Fixed 3 real release defects: xcodegen was clobbering the shared `Info.plist`; the archived app was missing `LSUIElement`/`CFBundleIconFile`; `AppIcon.icns` wasn't copied into the Xcode bundle.
- ☑ **R2** Sandbox build — `build-app.sh` produces an ad-hoc-signed bundle; `com.apple.security.app-sandbox` confirmed; launches as a menu-bar agent and quits cleanly.
- ☑ **R3** Icon QA — full 16→1024 ladder present (1024×1024 included).
- ☑ **R4** Copy fixed — "~95" → "110+ services across 12 categories" (README + metadata).
- ☑ **R5** URLs — support/marketing/privacy set to the repo (swap for a public site later).
- ☑ **V1** Uptime history + sparkline — local `StatusHistory` store (7-day/96-sample window), `Sparkline` view wired into rows.
- ☑ **V2** Accessibility — VoiceOver labels across panel + Settings, decorative elements hidden, keyboard-focusable.
- ☑ **V3** Maintenance styling — additive `isMaintenance` flag (no severity ripple), wrench glyph + "Under Maintenance".
- ☑ **V4** Live-feed canary — weekly CI hitting real endpoints, gated by `RUN_LIVE_TESTS` (skipped in normal runs).
- ☑ **V5** Localization scaffolding — `Localizable.xcstrings` seeded with English, `.process` resource rule.
- ☑ **M1/M3** Landing page (`site/`) + `CHANGELOG.md`.

**Remaining — needs you (🍎 / interactive):**
- ☐ **R6** Capture menu-bar popover screenshots (`scripts/screenshots.sh` + manual framing).
- ☐ Interactive notification-permission verification (GUI prompt).
- ☐ **A3–A7** App Store Connect record, Paid Apps agreement, privacy label, metadata/screenshot upload, archive+submit, review triage — see `RELEASE.md`.

**Watch-items:** `Resources/Info.plist` and `Resources/Info-Xcode.plist` are intentionally duplicated (SPM build vs. xcodegen) — keep in sync. Small-icon (16/32px) legibility unverified (dimensions correct, artwork not visually checked here).

---

## P0 — Pre-submission hardening (gates the release)

| ID | Story | Owner | Acceptance criteria | Est |
|----|-------|-------|---------------------|-----|
| R1 | **Verify the archive path** | 🤝 | `brew install xcodegen` → `xcodegen generate` produces a valid `Downbar.xcodeproj`; the app target builds (`xcodebuild -scheme Downbar build`). Confirms `project.yml` is correct *before* you rely on it. Archiving/signing still needs your Team. | 3 |
| R2 | **Sandbox smoke test** | 🤝 | Build the sandboxed `.app` (`scripts/build-app.sh`), launch it, and confirm under App Sandbox: status fetches succeed, notifications fire, and launch-at-login (`SMAppService`) registers. The #1 source of post-approval surprises. | 3 |
| R3 | **Icon QA all sizes** | 🤖 | Inspect `AppIcon.icns` at 16/32/128/256/512/1024 — legible at 16px in Finder, crisp at 1024 for the listing. Regenerate if the small sizes muddy. | 1 |
| R4 | **Fix marketing accuracy** | 🤖 | Docs/listing say "~95 services" — the catalog is actually **111**. Update README + `docs/app-store-metadata.md` to "110+ services across 12 categories." | 1 |
| R5 | **Support URL** | 🤝 | The listing requires a support URL. Quickest: point it at the repo's Issues page (or a one-page site). Fill into `docs/app-store-metadata.md`. | 1 |
| R6 | **Capture screenshots** | 🤝 | Run `scripts/screenshots.sh` to grab panel + Settings in light/dark at App Store dimensions (2880×1800). I can drive the capture; you pick the framing/services shown. | 2 |

## P0 — Release execution (your Apple account)

| ID | Story | Owner | Acceptance criteria | Est |
|----|-------|-------|---------------------|-----|
| A3 | **App Store Connect record** | 🍎 | Create the app record (bundle id `com.nathantarasiuk.downbar`), sign the **Paid Apps Agreement** (banking/tax), set price **Tier 3 ($2.99)**, category Developer Tools/Utilities. | 2 |
| A4 | **Privacy label** | 🍎 | Enter "Data Not Collected" per `docs/app-store-metadata.md`; add the `PRIVACY.md` URL. | 1 |
| A5 | **Upload metadata + screenshots** | 🍎 | Paste name/subtitle/description/keywords from the metadata draft; upload R6 screenshots. | 1 |
| A6 | **Archive, upload, submit** | 🍎 | In Xcode: set Team → Product > Archive → Distribute to App Store Connect; submit for review with `docs/review-notes.md`. | 2 |
| A7 | **Review triage** | 🍎 | Respond to any rejection; resubmit. (LSUIElement "no main window" is the likely flag — notes pre-empt it.) | — |

---

## P1 — v1.1 features (start now, ship after launch)

| ID | Story | Owner | Acceptance criteria | Est |
|----|-------|-------|---------------------|-----|
| V1 | **Uptime history + sparkline** | 🤖 | Persist a rolling window (e.g. last 24h/7d) of each service's indicator; show a small sparkline/timeline in the row. Storage stays local (privacy label unchanged). The headline v1.1 feature. | 8 |
| V2 | **Accessibility pass** | 🤖 | VoiceOver labels across panel + Settings; keyboard navigation through the panel list; Dynamic Type sanity. | 3 |
| V3 | **Maintenance-window styling** | 🤖 | Distinguish scheduled maintenance from a real degradation (currently both map to `.minor`) — a distinct glyph/label so a maintenance window doesn't read as an outage. | 2 |
| V4 | **Live-feed canary (CI)** | 🤖 | A scheduled GitHub Action that hits the real provider endpoints weekly and fails if parsing breaks — catches status-page format drift in the wild (the unit tests only cover fixtures). | 2 |
| V5 | **Localization scaffolding** | 🤖 | Extract user-facing strings to a String Catalog so future locales are a translation drop-in. | 3 |

---

## P2 — Growth (post-launch)

| ID | Story | Est |
|----|-------|-----|
| M1 | One-page landing/download site (links to App Store) | 3 |
| M2 | Launch assets — Show HN / Product Hunt / Reddit r/macapps post + demo GIF | 2 |
| M3 | "What's new" / changelog page for updates | 1 |

---

## Suggested sequencing
- **Day 1:** R3, R4, R5 (quick wins I can knock out now) + kick off A3/A4 (your ASC setup runs in parallel — agreement approval can lag).
- **Day 2:** R1 (verify xcodegen/archive) + R2 (sandbox smoke test) + R6 screenshots.
- **Day 3:** A5/A6 — archive, upload, submit. Then start V1 (uptime history) while in review.
- **Day 4–5:** V1 continues; V3, V4 as it bakes.
- **Review wait:** A7 triage; on approval, M1/M2 launch.

## Risks
- **Paid Apps Agreement (A3)** can gate going live even after approval — start it Day 1.
- **R1**: if `project.yml` doesn't generate cleanly, fixing it is the critical path to A6 — verify early.
- **R2 sandbox**: if launch-at-login or notifications misbehave under the sandbox, that's a code fix before submission, not after.
- **V1 storage**: keep history strictly local; adding any remote sync would change the "Data Not Collected" privacy label.

## Out of scope
Telemetry/analytics (would break the privacy label), Windows/Linux, widgets, multi-account,
direct-download/notarized build (App Store only this cycle).
