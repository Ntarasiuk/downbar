# App Store Listing — Downbar (draft)

Drafted copy for App Store Connect. Character limits noted inline; counts are
within Apple's maximums.

---

## App name

**Downbar**

(App Store "Name" max 30 chars. Optionally: `Downbar — Status Monitor` = 24 chars,
if a longer name reads better in search.)

## Subtitle (max 30 chars)

**Status pages in your menu bar**

(29 chars.)

## Promotional text (max 170 chars)

Watch the services you depend on — AWS, Stripe, GitHub, OpenAI and 110+ more —
from your menu bar. Get notified the moment one goes down, and again when it
recovers.

## Description

Downbar keeps the status of the services you depend on one glance away, right in
your menu bar.

Pick from a curated catalog of 110+ services across 12 categories — Developer
Tools, Cloud & Infrastructure, Data & Backend, Communication, Productivity,
Observability, Payments, Hosting, Identity, AI APIs and more — or paste any
public status page URL. Downbar polls them quietly in the background and shows a
small color-coded health meter: green when all is well, yellow for degraded,
orange for a partial outage, red for a major one.

When something you monitor goes down, Downbar posts a native notification — and
posts again when it recovers. Smart de-flapping means a momentary network blip
won't spam you with false alarms.

WHY DOWNBAR

• Live menu-bar health meter — the worst status across everything you watch, at
  a glance.
• 110+ curated services, organized into 12 categories with per-category "select
  all."
• Add any Statuspage.io, Instatus, or plain website URL.
• Notifications on outage and on recovery.
• Adjustable poll interval (default 5 minutes).
• Launch at login.

PRIVACY BY DESIGN

Downbar collects nothing. No accounts, no analytics, no telemetry, no tracking.
Status checks go directly from your Mac to the public status pages you choose —
there is no server in between. Your service list and preferences stay on your
device.

Downbar lives entirely in the menu bar (no Dock icon, no window to manage). Click
the meter icon any time to see every service and its current status.

## Keywords (max 100 chars)

```
status,uptime,monitor,outage,menu bar,downtime,statuspage,aws,devops,sre,alerts,incident
```

(96 chars including commas. No spaces after commas — Apple counts them; commas
already separate terms.)

## Support URL

`https://github.com/Ntarasiuk/downbar/issues` _(private repo for now — swap for a public support site if the repo isn't made public)_

## Marketing URL (optional)

`https://github.com/Ntarasiuk/downbar` _(private repo for now — swap for a public landing page later)_

## Privacy Policy URL

`https://github.com/Ntarasiuk/downbar/blob/master/PRIVACY.md` _(required field; private repo for now — host `PRIVACY.md` at a public URL once the repo or a site is public)_

## Category

- **Primary:** Developer Tools
- **Secondary:** Utilities

## Age rating

4+ (no objectionable content).

## Pricing

Tier 3 — **$2.99** (paid up front; Small Business Program, 15% commission).

---

## Privacy "nutrition label" answers (App Store Connect → App Privacy)

Enter these exactly when filling out the privacy questionnaire.

**"Do you or your third-party partners collect data from this app?"**
→ **No, we do not collect data from this app.**

This declares **Data Not Collected** for every category. Rationale to keep on
file in case of follow-up:

- No analytics, telemetry, crash reporting, or advertising SDKs are present.
- No user accounts or sign-in.
- The app's only network traffic is direct outbound HTTPS to the public status
  pages the user chooses to monitor; nothing is sent to a developer-operated
  server.
- The monitored-service list and preferences are stored locally
  (`UserDefaults`) and never leave the device.
- Notifications are generated and displayed locally by macOS.

Because nothing is collected, **no data types** are checked, and the "Data Used
to Track You" and "Data Linked to You" / "Data Not Linked to You" sections are
left empty.
