---
title: iOS distribution setup — TestFlight (and App Store comparison)
captured: 2026-05-01
source: user-request (post-macos-v1.2.0)
status: backlog
priority: medium
platforms: [iOS]
estimated_effort: 0.5–1 day initial setup, then ~5 min per build
---

# iOS distribution: TestFlight vs App Store

User wants to distribute Dicticus iOS to family and friends. macOS already
ships via notarized DMG + GitHub Releases + Sparkle. iOS can't use that
channel — Apple gates iOS distribution through App Store Connect.

## TestFlight (recommended for family/friends)

### What it is

Apple's first-party beta testing channel. Builds are uploaded to App
Store Connect, then made available to a list of testers via the
TestFlight app (free download from the App Store). Testers don't need
an App Store listing — just an invite link or email.

### Two flavours

| | Internal Testing | External Testing |
|---|---|---|
| Max testers | 100 | 10,000 |
| Tester eligibility | Must be on your App Store Connect team | Anyone with email + iPhone |
| Beta review | None | First build per version reviewed (usually <24h, sometimes minutes) |
| Build availability | Immediate after processing | After beta review approves |
| Build expiration | 90 days | 90 days |

For family/friends, **External Testing** is right — no need to add them
to your dev team, just invite them by email or share a public TestFlight
link.

### Costs

Covered by the **$99/year Apple Developer Program** membership (already
paying — that's what produced the Developer ID Application cert). No
additional fee for TestFlight.

### Process (estimated 30–60 min initial setup)

1. **App Store Connect** (https://appstoreconnect.apple.com): create
   a new app record. Bundle ID `com.dicticus.ios` (must match
   `iOS/project.yml`). Picks up icon + display name from Xcode upload.
2. **Xcode**: Product → **Archive** (with iOS scheme + "Any iOS Device"
   target). When archive completes, Organizer opens.
3. **Distribute App** → "App Store Connect" → "Upload". Xcode handles
   signing automatically with the dev account.
4. **App Store Connect** → "TestFlight" tab → wait for processing
   (~5–15 min) → add internal testers immediately, or set up an
   external test group with public link.
5. **Testers**: install TestFlight app from App Store → tap invite
   link → install Dicticus from TestFlight → updates appear
   automatically when new builds are uploaded.

### Per-build cadence after setup

~5 min: Archive → Distribute → wait for processing → testers get
notification on their phones.

### Limitations to know

- 90-day expiration: builds stop launching after 90 days. New build
  resets the clock.
- Requires iPhone with iOS 16+ (TestFlight app requirement).
- External Testing's first build per version is reviewed; subsequent
  patch builds usually skip review.

## Apple App Store (full public distribution)

### What it is

The "real" App Store listing. Anyone can search and install, with
ratings/reviews/screenshots, etc.

### Costs

Same $99/year Apple Developer Program membership. No additional fee.

### Process (estimated 1–2 weeks first time, much faster after)

1. Same App Store Connect app record as TestFlight (one record
   serves both channels).
2. Submit build through Xcode the same way (Archive → Distribute).
3. **Required metadata before submission**:
   - Screenshots (specific sizes per device class — iPhone 6.5",
     6.7", iPad 12.9", etc.)
   - App description (4000 chars)
   - Keywords (100 chars)
   - Support URL (a webpage where users can ask questions)
   - **Privacy policy URL** (mandatory; must explain data
     practices). Dicticus's privacy story is straightforward
     ("nothing leaves the device") which actually plays well in
     review.
   - App icon (1024×1024 PNG)
   - Age rating questionnaire
   - Pricing tier (free vs paid, with regional adjustments)
4. **App Review**: typically 24–48h. First-time submissions are
   sometimes flagged for clarification (often privacy-related). Apple
   tends to *like* on-device-only apps.
5. After approval: app goes live, anyone can install.

### Trade-offs

| | TestFlight (External) | App Store |
|---|---|---|
| Audience | People you know + invite | Anyone in 175+ regions |
| Setup work | Minimal | Screenshots, description, privacy policy, etc. |
| Review burden | First build per version, fast | Every release reviewed |
| Build expiration | 90 days | None |
| Discoverability | None (invite-only) | Searchable in App Store |
| Updates | Automatic via TestFlight app | Automatic via App Store |
| Reputation | None | Public ratings/reviews |
| Right time | When you want feedback before going public | When the app is feature-complete and you want it discoverable |

### Which to do first

**TestFlight first, always.** It's a strict subset of the App Store
upload flow:
- Same App Store Connect app record
- Same Archive → Upload flow from Xcode
- Same metadata fields (just optional for TestFlight)

So the work isn't wasted — going from TestFlight to App Store later is
just "fill in the metadata fields you skipped + submit for review."

## When to schedule this

After macos-v1.2.0 has soaked for a week or two on macOS (Sparkle
adoption stable, no surprise bug reports). Then this becomes a
focused 1-day phase: App Store Connect setup, first archive upload,
invite three family members, validate end-to-end.

Phase suggestion: `21-ios-testflight-distribution`. Drives one user
story: "I can send my brother a link, and he can install Dicticus on
his iPhone in under 5 minutes."

## Open questions for that phase

- App Store Connect account already has an app record from earlier
  iOS work? Or is this from scratch?
- Bundle ID conflicts? `com.dicticus.ios` is currently the iOS
  PRODUCT_BUNDLE_IDENTIFIER — confirm it's available on App Store
  Connect.
- Privacy policy: needs to be hosted somewhere. Could use the existing
  `maksim-101.github.io/dicticus-macos/` GitHub Pages site or a
  dedicated domain.
- Screenshots: the macOS DESIGN.md exists; need iOS-specific shots
  (iPhone 6.5" + 6.7" mandatory, iPad optional).
