# App Store Listing — Downbar (draft)

Drafted copy for App Store Connect. Character limits noted inline; counts are
within Apple's maximums.

---

## App name

**Downbar**

(App Store "Name" max 30 chars. Optionally: `Downbar — Status Monitor` = 24 chars,
if a longer name reads better in search.)

## Subtitle (max 30 chars)

**Your stack. One glance.**

(23 chars.)

## Promotional text (max 170 chars)

The infrastructure your work runs on — AWS, Stripe, GitHub, OpenAI and 110+ more —
watched from your menu bar. The instant it breaks, you know. And when it's back.

(163 chars.)

## Description

Every service you depend on. One glance.

Downbar lives in your menu bar and watches the infrastructure your work runs on —
AWS, Stripe, GitHub, OpenAI, Cloudflare, and 110+ more. The moment something
breaks, you know. The moment it recovers, you know that too.

No dashboard to open. No tab to keep alive. Just a quiet meter that turns the
instant the internet doesn't.

MONITOR EVERYTHING

110+ services across 12 categories. Or paste any status page — Statuspage,
Instatus, or a plain website. If it has a pulse, Downbar reads it.

KNOW INSTANTLY

One color-coded meter shows the worst status across everything you watch. Green,
all clear. Yellow, degraded. Red, down. Native notifications fire the moment a
service drops — and again when it's back. Smart de-flapping kills the false
alarms.

OWN YOUR DATA

No account. No analytics. No telemetry. No server in between. Checks go straight
from your Mac to the source. Your list never leaves your device.

Downbar runs entirely in the menu bar — no Dock icon, no window to manage, nothing
to maintain. Set it once. Trust it forever.

Built for the people who keep things running.

## Keywords (max 100 chars)

```
status,uptime,monitor,outage,menu bar,downtime,statuspage,aws,devops,sre,alerts,incident
```

(96 chars including commas. No spaces after commas — Apple counts them; commas
already separate terms.)

## Support URL

`https://downbar.app/support` _(live — returns 200)_

## Marketing URL (optional)

`https://downbar.app`

## Privacy Policy URL

`https://downbar.app/privacy` _(live — returns 200)_

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
