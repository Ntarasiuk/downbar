# Downbar — project notes for Claude

## Site DMG: regenerate every time

The landing site (`site/`, deployed to Cloudflare Pages on push to master) serves
the app as a direct download at `site/dl/Downbar-<version>.dmg`. **Never reuse a
stale DMG — regenerate it from the current build every time** the app changes or
a release/site update touches the download:

1. `./scripts/build-app.sh` then `./scripts/make-dmg.sh` (produces
   `Downbar-<version>.dmg` at the repo root; version comes from
   `Resources/Info.plist`).
2. Copy it to `site/dl/Downbar-<version>.dmg` and remove the old version's file.
3. Update every versioned reference: the `/dl/latest` redirect target in
   `site/_redirects` (all download buttons point at `/dl/latest`, so they never
   go stale), the version string in `site/index.html`, and the "Latest" release
   section (with its versioned download link) in `site/changelog.html`.
4. Bump the Homebrew cask (`~/code/homebrew-tap/Casks/downbar.rb`, GitHub
   `Ntarasiuk/homebrew-tap`): set `version` and `sha256` (`shasum -a 256` of the
   new site DMG), commit, push. The site's copyable install command is
   `brew install --cask ntarasiuk/tap/downbar`.

Notes:
- `*.dmg` is gitignored **except** `site/dl/*.dmg` — the site DMG must be
  committed so the Pages Git integration deploys it.
- Never request a new `/dl/*.dmg` URL before the Pages deploy is live: until
  then the edge serves the HTML fallback, and `/dl/*` caches it for a year
  (`immutable`). If it happens, purge the URL or ship under a new filename.
- `site/install.sh` is the `curl -fsSL https://downbar.app/install | sh`
  installer (`/install` is a 200 rewrite in `site/_redirects`). It installs
  from `/dl/latest`, so it needs **no** per-release bump.
- The DMG must be Developer ID–signed and notarized before it opens cleanly on
  other Macs; `make-dmg.sh` wraps whatever signature `Downbar.app` already has
  (ad-hoc by default — Gatekeeper rejects that). See RELEASE.md.
- The download is free and Apple-silicon-only (arm64); site copy reflects that.
