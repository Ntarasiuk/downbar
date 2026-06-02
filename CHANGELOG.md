# Changelog

All notable changes to Downbar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Uptime history: per-service rolling record of recent checks, surfaced in the menu.
- Accessibility pass: VoiceOver labels, Dynamic Type support, and improved contrast throughout.
- Distinct styling for scheduled-maintenance states, separating them visually from outages.

### Changed
- Localization: user-facing strings extracted for translation.

## [1.0.0] - 2026-06-02

### Added
- Curated catalog of 110+ public status pages across 12 categories (AI, cloud,
  developer tools, payments, and more), monitored concurrently in the menu bar.
- Seven status-page adapters behind a single `Indicator` model: Statuspage.io,
  Instatus, AWS Health, Apple System Status, Google Cloud, Azure, and a generic
  website/server uptime check.
- Down and recovery notifications with de-flap debouncing, so a momentary blip
  doesn't spam alerts.
- Offline awareness: the app distinguishes "no internet here" from "the service
  is down" and reflects it in the menu-bar icon.
- Per-service mute to silence notifications for noisy or low-priority services.
- Severity threshold so notifications only fire at or above a chosen impact level.
- Notification deep-link: clicking an alert opens the relevant service's status page.
- Incident detail in the menu, showing the active incident title alongside status.
- Drag-to-reorder services in the panel.
- First-launch onboarding to pick the services you care about.
- App Store packaging as a $2.99 LSUIElement menu-bar app (macOS 14+).

[Unreleased]: https://github.com/Ntarasiuk/downbar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Ntarasiuk/downbar/releases/tag/v1.0.0
