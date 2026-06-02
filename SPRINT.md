# Downbar — Sprint 1: Ship v1.0 on the Mac App Store ($2.99)

**Sprint goal:** Take Downbar from "working on my machine" to a paid ($2.99) Mac App
Store listing — with enough test coverage that a status-page format change can't
silently break monitoring.

**Why App Store:** fastest path to a *paid* app. Apple handles payment, tax/VAT,
refunds, fraud, licensing, and auto-updates — so no Developer ID notarization scripting,
no DMG, no Sparkle, and **no licensing/payment code to build**. Cost is sandboxing
(trivial here — outbound HTTPS only) + App Review. Apple's cut is 15% under the Small
Business Program.

**Duration:** ~1 week of build work, then App Review wait (~1–3 days) · **Capacity:** 1 dev
**Definition of done:** sandboxed build accepted by App Review, priced at $2.99 (Tier 3),
live on the store; provider parsing covered by tests; no P0 bugs open.

> Status legend: ☐ todo · ◐ in progress · ☑ done
> Recently landed (pre-sprint): per-category "Select all" in Settings; notification
> de-flapping (ignore transient `.unknown` blips so outages don't double-alert).

---

## ✅ Sprint result (2026-06-02) — `swift build` + `swift test` green (41 tests, 0 failures)

**Done (code complete & verified):**
- ☑ **B1–B4** Tests: `DownbarTests` target + CI yaml; 23 provider fixture tests (all 7 providers, via injected `URLSession` + `MockURLProtocol`), 12 Indicator/aggregate tests, catalog-integrity tests.
- ☑ **C1** App icon: `Resources/AppIcon.icns` + 1024px master, reproducible `scripts/make-icon.sh`, referenced in Info.plist & build script.
- ☑ **A1** App Sandbox: `Resources/Downbar.entitlements` (app-sandbox + network.client), hardened-runtime codesign in `build-app.sh`.
- ☑ **A2** Xcode wrapper: `project.yml` (XcodeGen) + `RELEASE.md`. *(needs `brew install xcodegen` to generate — unverified, see below.)*
- ☑ **D1–D3** Reliability: offline awareness (`NWPathMonitor`, `isOffline`, "No connection" summary), retry-once on `.unknown`, refresh-on-wake.
- ☑ **F1–F3** Notifications: per-service mute, severity threshold (`minSeverity`), tap-to-open deep-link delegate.
- ☑ **E1–E3** UX: drag-to-reorder monitored services, first-run onboarding screen, incident-title detail (Statuspage/Instatus → ServiceRow).
- ☑ **A4/A5/A6 drafts + G1**: `README.md`, `PRIVACY.md`, `docs/app-store-metadata.md`, `docs/review-notes.md`, `scripts/screenshots.sh`.
- 🐛 **Bug surfaced & fixed:** "Google Gemini" and "Google Cloud" shared the same `gcp:status.cloud.google.com` id (catalog id collision) — replaced Gemini with "Google AI Studio".

**Remaining — manual (your Apple account / GUI), not code:**
- ☐ Run `brew install xcodegen && xcodegen generate`, archive in Xcode, set your Team.
- ☐ **A3** App Store Connect: create app record, sign Paid Apps agreement (banking/tax), set price **Tier 3 ($2.99)**.
- ☐ **A4/A5** Enter privacy label (Data Not Collected), upload metadata + screenshots (run `scripts/screenshots.sh`).
- ☐ **A6** Submit to App Review (use `docs/review-notes.md`).
- ☐ Sandbox smoke-test on a clean account (launch-at-login, notifications, fetches) before submitting.

---

## P0 — Must ship (blocks release)

### Epic A · App Store distribution
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| A1 | **App Sandbox + entitlements** | Enable App Sandbox; add `com.apple.security.network.client` (outbound only — that's all the providers need). App runs fully sandboxed: polling, notifications, and launch-at-login (`SMAppService.mainApp` is sandbox-safe) all still work. | 3 |
| A2 | **Xcode project / archive target** | SPM executable can't upload to App Store Connect directly — wrap in an `.xcodeproj`/workspace (or `xcodebuild -scheme`) that produces a signed `.pkg` via "Distribute App → App Store Connect". Keep `Package.swift` as the source of truth for code. | 5 |
| A3 | **App Store Connect setup** | Create the app record, bundle ID `com.nathantarasiuk.downbar`, sign the Paid Apps agreement, set price **Tier 3 ($2.99)**, fill categories (Developer Tools / Utilities). | 2 |
| A4 | **Privacy nutrition label** | Declare data collection = **none** (all checks are direct to public status pages, no telemetry, no accounts). Add a one-line privacy policy URL. | 1 |
| A5 | **Store metadata + screenshots** | Name, subtitle, description, keywords, support URL; 2–3 screenshots of the panel + Settings (light/dark). | 3 |
| A6 | **App Review readiness** | Reviewer notes (menu-bar `LSUIElement` app, no login required, what the bars mean). Submit; triage any rejection. | 2 |

### Epic B · Correctness & Tests
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| B1 | **Test target + CI** | Add `DownbarTests` to `Package.swift`; `swift test` runs. GitHub Actions runs build + test on PR. | 2 |
| B2 | **Provider fixture tests** | Saved JSON/HTML fixtures for each of the 7 providers (Statuspage, Instatus, Website, AWS, Apple, GCP, Azure) → assert correct `Indicator`. Inject a mocked fetch (providers currently call `Self.session` directly — minimal refactor behind the `StatusProvider` protocol). Covers the "format changed, we show wrong status" risk. | 5 |
| B3 | **Indicator + notify tests** | Unit-test `Indicator(statuspageIndicator:)`, severity ordering, `aggregate` (unknown doesn't mask a real outage), and `notifyIfChanged` transitions incl. the de-flap path. | 2 |
| B4 | **Catalog integrity test** | Assert every `CatalogEntry.id` is unique, every seed host exists in the catalog, all URLs parse. Guards the "seeded service shows enabled" contract. | 1 |

### Epic C · App identity
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| C1 | **App icon** | Real `AppIcon` asset (all required sizes, incl. 1024px for the store). Shows in Finder, About, notifications, and the listing. Derive from the bar-meter motif. | 3 |
| C2 | **Menu-bar icon audit** | Verify the colored (non-template) `MenuBarIconRenderer` in light/dark menu bars, notch displays, and on appearance change. | 2 |

---

## P1 — Should ship (cut only if review timing forces it)

### Epic D · Reliability
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| D1 | **Offline awareness** | `NWPathMonitor`: when offline, pause polling and show a "No connection" state instead of flapping every service to `.unknown`. Resume + refresh on reconnect. | 3 |
| D2 | **Retry/backoff** | One transient failure retries once before committing `.unknown`; fewer false grays. | 2 |
| D3 | **Sleep/wake refresh** | Refresh on `NSWorkspace.didWakeNotification` so status isn't stale after the lid opens. | 1 |

### Epic E · UX completeness
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| E1 | **Reorder monitored services** | `StatusMonitor.move(from:to:)` exists but isn't exposed — add drag-to-reorder in Settings → Services. Persists. | 3 |
| E2 | **First-run onboarding** | First launch shows a one-screen intro (what the bars mean, "open Settings to pick services") instead of dropping cold into 8 seeded services. | 2 |
| E3 | **Incident detail** | Show the latest active incident title (Statuspage/Instatus first) in the row, not just the summary string. | 5 |

### Epic F · Notifications depth
| ID | Story | Acceptance criteria | Est |
|----|-------|---------------------|-----|
| F1 | **Per-service mute** | Mute notifications for a noisy service while still monitoring it. | 3 |
| F2 | **Severity threshold** | "Only notify for major/critical" so minor/maintenance blips stay quiet. | 2 |
| F3 | **Notification deep-link** | Clicking a notification opens that service's status page. | 1 |

---

## P2 — Nice to have (post-launch / v1.1)
| ID | Story | Est |
|----|-------|-----|
| G1 | README + screenshots (also feeds the listing) | 2 |
| G2 | Uptime history + row sparkline | 8 |
| G3 | Accessibility pass (VoiceOver, keyboard nav in panel) | 3 |
| G4 | Localization scaffolding | 3 |
| G5 | Maintenance-window styling (distinct from real degradation) | 2 |

---

## Suggested sequencing
- **Day 1–2:** B1–B4 (lock correctness first). C1 icon in parallel.
- **Day 3:** A1 sandbox + A2 archive target — get a signed build uploading early; sandbox surprises are the #1 schedule risk.
- **Day 4:** A3 + A4 + A5 (Connect record, price, privacy, metadata, screenshots). C2.
- **Day 5:** D1–D3, E1–E2.
- **Day 6:** F1–F3, E3 if time. A6 submit to review.
- **Review wait (~1–3 days):** fix rejections, then release.

## Risks / watch-items
- **A1 sandbox** is the top risk: confirm `SMAppService` launch-at-login, `UserNotifications`, and `URLSession` to status hosts all work *after* enabling the sandbox. Test on a clean account.
- **A2**: SPM-only projects don't upload to App Store Connect — budget time for the Xcode wrapper. Keep `Package.swift` authoritative.
- **A3** needs a paid Apple Developer account + signed Paid Apps agreement (banking/tax forms) — start this Day 1; the agreement can gate going live even after approval.
- **App Review** for menu-bar/`LSUIElement` apps occasionally flags "no main window" — pre-empt with clear reviewer notes (A6).
- **B2** may require injecting the URL session into providers — keep the refactor minimal.

## Out of scope this sprint
Direct-download/notarized build, Sparkle, custom licensing/payment (Apple handles it),
Windows/Linux, widgets, multi-account.
