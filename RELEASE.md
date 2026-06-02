# Releasing Downbar to the Mac App Store

Downbar ships as a SwiftUI `MenuBarExtra` app (`LSUIElement`, macOS 14+). The
day-to-day build (`scripts/build-app.sh`) produces an ad-hoc-signed, sandboxed
`.app` for local use. The Mac App Store requires a signed **archive** uploaded
through Xcode / App Store Connect, which an SPM executable target can't produce
directly — so we generate a thin Xcode project around the same sources with
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

## One-time setup

- **Apple account:** enrolled with Apple ID `ntarasiuk@gmail.com` — **Individual**
  enrollment ($99/yr). Note: this Apple ID permanently owns the developer account
  and apps (migrating to another Apple ID later requires an Apple support ticket),
  and Apple mandates two-factor auth on it. Individual enrollment displays the
  developer's **legal name** publicly on the listing (the email is never shown);
  switch to Organization enrollment only if a business name must appear instead.
- Apple Developer Program membership (paid).
- Xcode installed and signed in with your Apple ID (Xcode > Settings > Accounts).
- XcodeGen:

  ```bash
  brew install xcodegen
  ```

## Build the app icon (reproducible)

```bash
./scripts/make-icon.sh
```

This renders `Resources/AppIcon-1024.png` and packs `Resources/AppIcon.icns`
(the three-ascending-green-bars motif). The `.icns` is referenced from
`Resources/Info.plist` via `CFBundleIconFile` and bundled by both
`build-app.sh` and the Xcode project.

## Archive & upload

1. Generate the Xcode project from `project.yml`:

   ```bash
   xcodegen generate
   ```

2. Open it:

   ```bash
   open Downbar.xcodeproj
   ```

3. In Xcode, select the **Downbar** target > **Signing & Capabilities**:
   - Set your **Team**.
   - Confirm **Automatically manage signing** is on.
   - Confirm the bundle id is `com.nathantarasiuk.downbar`.
   - Confirm **App Sandbox** is present (from `Resources/Downbar.entitlements`:
     `com.apple.security.app-sandbox` + `com.apple.security.network.client`).
   - Confirm **Hardened Runtime** is enabled.

4. Set the destination to **Any Mac** (not a simulator/`My Mac`), then
   **Product > Archive**.

5. When the Organizer opens, select the new archive >
   **Distribute App** > **App Store Connect** > **Upload**, and follow the
   prompts (let Xcode manage signing / upload the dSYMs).

> Note: `project.yml`, `Downbar.xcodeproj`, and the generated `.iconset` are
> build artifacts — regenerate them; they don't need to be committed.

## App Store Connect checklist

In [App Store Connect](https://appstoreconnect.apple.com):

1. **Create the app record**: My Apps > **+** > New App.
   - Platform: macOS.
   - Bundle ID: `com.nathantarasiuk.downbar` (register it under
     Certificates, Identifiers & Profiles first if it's not in the list).
   - SKU: e.g. `downbar`.
2. **Paid Apps Agreement**: Business > Agreements — sign the **Paid
   Applications** agreement and complete banking/tax info. (Required before a
   paid app can be reviewed or sold.)
3. **Pricing**: Pricing and Availability — set price to **Tier 3 ($2.99 USD)**.
4. **App Privacy**: App Privacy > set the label to **Data Not Collected**
   (Downbar makes only outbound HTTPS requests to public status pages; it
   collects no user data, has no accounts, and stores only local preferences).
5. **App information / version metadata**: name, subtitle, category
   (Utilities / Developer Tools), description, keywords, support URL,
   screenshots, and the 1024×1024 marketing icon
   (`Resources/AppIcon-1024.png`).
6. Attach the uploaded build to the version, then **Submit for Review**.

## Notes / verification

- `Resources/Info.plist` and `Resources/Downbar.entitlements` pass
  `plutil -lint`.
- The sandbox grants only `network.client` (outbound HTTPS), which is all the
  status providers need — no server, file, or other entitlements.
