# Downbar

A tiny macOS menu-bar app that watches the status pages you care about and tells
you the moment something breaks — before your users do.

Downbar lives in the menu bar as a small **health meter**. Pick the services you
depend on from a curated catalog of 110+ across 12 categories (or paste any status
page URL), and Downbar polls them quietly in the background. When something goes
down or recovers, you get a native notification. No dashboard to keep open, no
account to create, no data leaving your Mac except the checks themselves.

## Features

- **Menu-bar health meter** — a colored bar-meter icon shows the worst status
  across everything you monitor at a glance: green (operational), yellow
  (degraded), orange (partial outage), red (major outage), gray (unreachable).
- **110+ curated services, 12 categories** — Developer Tools, Cloud & Infra,
  Data & Backend, Communication, Productivity, Observability & APM, Payments,
  Hosting, Identity & Auth, AI APIs, and more. Pick per-service or "Select all"
  per category.
- **Add any status page** — paste a Statuspage.io, Instatus, or plain website
  URL and Downbar monitors it too.
- **Watch only the components you care about** — on any Statuspage.io service,
  pick specific components (e.g. the Cloudflare data center your users hit)
  and Downbar ignores outages everywhere else on that page.
- **Native notifications** on down *and* recovery, with transient-blip
  de-flapping so a momentary unreachable reading doesn't spam alerts.
- **Multiple status formats** — Statuspage.io, Instatus, plain website reach
  ability, and first-party feeds for AWS, Apple, Google Cloud, and Azure.
- **Adjustable poll interval** (default 5 minutes).
- **Launch at login** (sandbox-safe `SMAppService`).
- **Zero data collection** — see [PRIVACY.md](PRIVACY.md).

## Screenshots

<img src="docs/screenshots/panel.png" alt="The Downbar menu panel showing a partial service outage: OpenAI and Google Cloud degraded, Cloudflare minor, the rest operational with green sparklines" width="580">

| Services | General |
| --- | --- |
| ![Settings — pick services to monitor](docs/screenshots/settings-services.png) | ![Settings — refresh interval, notifications, webhook](docs/screenshots/settings-general.png) |

## How it works

Downbar is a `MenuBarExtra` SwiftUI app (`LSUIElement` — no Dock icon, no main
window). A single `StatusMonitor` owns the service list and the poll timer, and
on each tick fetches every monitored service concurrently.

Each service declares a **provider** — the status-page format it exposes — and
the monitor dispatches to the matching adapter:

| Provider | What it reads |
| --- | --- |
| `statuspage` | Statuspage.io `summary.json` (`status.indicator`) |
| `instatus` | Instatus `summary.json` |
| `website` | Plain HTTPS reachability of a site/server |
| `aws` | AWS Health status feed |
| `apple` | Apple System Status |
| `gcp` | Google Cloud status |
| `azure` | Azure status |

Every provider normalizes its result into a shared `Indicator` enum
(`none` → `minor` → `major` → `critical`, plus `unknown` for fetch/parse
failures). The menu-bar icon shows the **aggregate** — the worst real indicator
across all services — and an `unknown` reading never masks a genuine outage.

All requests are direct outbound HTTPS to the public status endpoints you choose.
There is no backend, no proxy, and no telemetry.

## Build

Requires macOS 14+ and a Swift 6 toolchain.

```bash
swift build          # debug build of the SPM executable
swift test           # run the test suite
```

To produce a runnable, `LSUIElement` `.app` bundle (release build, ad-hoc
signed):

```bash
scripts/build-app.sh
open Downbar.app
```

`Package.swift` is the source of truth for the code. The App Store build wraps
this same target in an Xcode archive target for submission.

## License

The code is MIT-licensed — see [LICENSE](LICENSE). The "Downbar" name and the
app icon are not covered by the license and remain © Nathan Tarasiuk.
