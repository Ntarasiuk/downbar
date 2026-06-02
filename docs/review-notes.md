# App Review — Reviewer Notes

Paste the section below into App Store Connect → **App Review Information →
Notes**. It pre-empts the rejections that menu-bar / `LSUIElement` apps commonly
hit.

---

## Notes for the reviewer

Thank you for reviewing Downbar.

**Downbar is a menu-bar (status-bar) utility — it has no Dock icon and no main
window by design.** It ships as an `LSUIElement` app, the standard pattern for
menu-bar accessories on macOS.

**Where the UI is:** After launch, look in the **menu bar** (top-right of the
screen). Downbar adds a small **bar-meter icon**. **Click that icon** to open the
app's panel, which lists every monitored service and its current status. The
panel also contains **Settings**, where you choose which services to monitor and
adjust the poll interval.

If you don't see the icon immediately, the menu bar may be full — the icon
appears once there is room, or you can quit other menu-bar apps to make space.
The icon is colored to reflect overall health: green = all operational, yellow =
degraded, orange = partial outage, red = major outage, gray = checking /
unreachable.

**No account or login is required.** There is no sign-in, no paywall inside the
app, and no setup step. The app is fully functional immediately after launch
with a small set of default services already monitored.

**Network use:** Downbar makes only **outbound HTTPS requests to public status
pages** — the same pages anyone can open in a browser (e.g. Statuspage.io
`summary.json` feeds, AWS / Apple / Google Cloud / Azure status feeds, and any
website the user adds). It uses the `com.apple.security.network.client`
entitlement only. There is **no inbound networking**, no developer-operated
backend, and **no data collection or telemetry** (the App Privacy label is set
to "Data Not Collected").

**Notifications:** Downbar requests Notification authorization so it can alert the
user when a monitored service goes down or recovers. Notifications are generated
locally; nothing is sent to a push server.

**Launch at login** uses `SMAppService.mainApp` and is fully sandbox-safe; it is
user-toggleable.

**How to test quickly:**
1. Launch the app.
2. Click the bar-meter icon in the menu bar to open the panel.
3. Open Settings from the panel to enable/disable services or add a status page
   URL.
4. (Optional) Lower the poll interval to see status refresh sooner.

Please reach out at ntarasiuk@gmail.com with any questions during review.
