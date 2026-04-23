# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- ✅ **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (shipped 2026-04-22)
- ✅ **v2.1 Keyboard Extension & Polish** — Phases 17+ (shipped 2026-04-23)

---

## Completed Phases

| Phase | Milestone | Scope | Status | Result |
|-------|-----------|-------|--------|--------|
| 12. Shared Code | v2.0 | Shared pipeline, ITN, Dictionary, GRDB | ✅ Done | Success |
| 13. iOS Pipeline | v2.0 | FluidAudio iOS, App Intent, Live Activity | ✅ Done | Success |
| 14. Model Mgmt | v2.0 | Onboarding, Model Provisioning (2.7GB) | ✅ Done | Success |
| 15. History & Dict | v2.0 | History View, Dictionary UI, FTS5 | ✅ Done | Success |
| 16. Universal App | v2.0 | iPad Layout, WhatsNew, Launch Screen | ✅ Done | Success |
| 17. Keyboard Extension | v2.1 | Custom iOS Keyboard with in-app dictation — text at cursor without app switching | ✅ Done | Success |

## Upcoming Phases

| Phase | Milestone | Scope | Status | Result |
|-------|-----------|-------|--------|--------|
| 17.5. Inline Shortcut Dictation | v2.1 | Auto-return App Intent flow — record, transcribe, copy to clipboard inline via Shortcut, returning user to previous app automatically (INSERTED) | In progress (1/2 plans) | - |
| 18. iCloud Sync | v2.1 | CloudKit integration for Dictionary & History | Not started | - |
| 19. AI Cleanup iOS | v2.1 | llama.cpp Metal for on-device AI cleanup | Not started | - |

---

### Phase 17: Keyboard Extension
**Goal:** Implement a custom iOS keyboard extension with a QWERTZ layout and an integrated dictation button that bounces to the main app for recording and auto-inserts the result at the cursor.

**Requirements:** KEYB-01, KEYB-02

**Plans:**
- [x] 17-01-PLAN.md — Foundation, Target Setup, and URL Scheme
- [x] 17-02-PLAN.md — Keyboard UI (SwiftUI QWERTZ Layout)
- [x] 17-03-PLAN.md — Dictation Loop and Result Delivery
- [x] 17-04-PLAN.md — Live Activity Stop Button and Polish

---

### Phase 17.5: Inline Shortcut Dictation — Auto-Return Flow (INSERTED)
**Goal:** Enhance the Action Button shortcut so the entire dictation flow (record, transcribe, copy to clipboard) happens with minimal friction, showing a stripped-down UI and guiding the user back to their previous app.

**Requirements:** KEYB-02 (text at cursor without app switching — alternative approach)

**Plans:** 2 plans
- [x] 17.5-01-PLAN.md — Intent flag wiring + ViewModel shortcut-launch lifecycle
- [ ] 17.5-02-PLAN.md — Shortcut-mode UI (minimal chrome, swipe-back hint, WhatsNew suppression)

---
*Last updated: 2026-04-23 — Phase 17.5 plan 01 complete (1/2 plans done)*
