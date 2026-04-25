---
phase: 19
slug: ai-cleanup-ios
type: uat-findings
created: 2026-04-25
source: physical-device UAT 2026-04-25 (post-Phase-19 ship-readiness pass)
feeds_into: [DESIGN.md, 19.5, 19.6, 19.7, B2-hotfix]
---

# Phase 19 — UAT Findings & Follow-On Routing

User-reported issues from physical-device UAT after Phase 19 code-complete. Each item is mapped to the follow-on phase that owns it. This file is consumed by `/gsd-discuss-phase` for 19.5, 19.6, and 19.7 so we don't re-derive context.

> **Round 2 (post-19.7 ship):** see `19-UAT-FINDINGS-postship.md` for B5/B6 (Swiss currency mistranslation + decimal separator) and S7/S8 (cross-platform 19.5 scope). Both files must be read together when planning 19.5.

---

## Bugs

| ID | Issue | Owner Phase | Notes |
|----|-------|-------------|-------|
| **B1** | Action Button setup appears twice — dedicated tab + Setup Guides | **19.6** (UX) | Artifact from abandoned deep-link approach (we can't link into iOS Action Button settings). Just remove the dedicated tab, keep entry in Setup Guides. |
| **B2** | After app relaunch, prompts to re-download **Parakeet ASR model** even though it was downloaded; eventually figures out it's cached | **19.5** (integrated hotfix) | Phase-14 territory (`ModelProvisioning`). Investigate via `/gsd-debug` first to scope. **NOT** the Gemma model — user clarified. |
| **B3** | "15 Franken 50" → bleibt wörtlich; "15 Euro 50" → "€15.50" funktioniert | **19.5** | LLM has Euro examples; CHF unrepresented. Solution: deterministic post-LLM Swiss currency formatter via `Locale("de_CH")` + `NumberFormatter(currencyCode: "CHF")` per Swiss-German-research §2. Don't rely on prompt alone. |
| **B4** | Thousands separator renders as `1.250` (German point); should be `1'250` (Swiss apostrophe) when Swiss toggle ON | **19.5** | Same fix as B3 — Apple's CLDR-backed `NumberFormatter` with `de_CH` locale produces `1’250` natively. Wire it into the post-LLM safety-net (D-19) as a number-format pass. |

## UX

| ID | Issue | Owner Phase | Notes |
|----|-------|-------------|-------|
| **U1** | Toggle "AI Cleanup" ON ≠ model present. User dictated, didn't realize Gemma still needed downloading | **19.6** | Toggle activation should either auto-trigger the download or show a sticky home-screen banner: "AI Cleanup wartet — Modell laden". |
| **U2** | "App neu starten" message after model download is plain text — should be actionable | **19.6** | Add "Jetzt neustarten" button (legitimate `exit(0)` for in-app re-launch flow) OR dismissible banner with explicit Tap-to-Acknowledge. |
| **U3** | Start Dictation button is too small on Home; **must be dynamic** based on clipboard state | **19.6** | Empty clipboard → hero-sized button dominating Home. Clipboard-text present → button compresses, text area appears. Smooth animated transition (matchedGeometryEffect-style), not abrupt. |
| **U4** | Live dictation pane truncates long text mid-recording — user can't see what's been transcribed | **19.6** | Wrap the live-text view in `ScrollView` with auto-scroll-to-end. |
| **U5** | Auto-stop on silence creates anxiety during long dictations ("if I pause too long it cuts me off") | **19.6** | New Settings toggle: "Diktat automatisch beenden bei Stille" (default ON, but allow OFF for users who think aloud). |
| **U6** | History rows are 3-line capped with no expand mechanism; search-match invisible (user can't see WHERE the match was) | **19.6** | Tap-to-expand rows + highlight search-match span when filtering via FTS5. |
| **D1** | App icon inconsistent across platforms; latest macOS build (Today 06:08, 23.8 MB) shows **no icon at all** in Finder | **19.7** | Adopt iOS icon as canonical; verify `AppIcon.appiconset` config in `macOS/Dicticus.xcodeproj`. The missing-icon issue is a likely separate bug — investigate. |
| **D2** | iOS mic icon currently too small | **19.6** | Enlarge per DESIGN.md tokens once they exist. |

## macOS Regressions / Hygiene

| ID | Issue | Owner Phase | Notes |
|----|-------|-------------|-------|
| **M1** | macOS hotkeys (FN + regular) no longer trigger dictation; app restart does nothing | **19.7** | Root cause: multiple Dicticus.app installations at different paths produce multiple TCC entries; macOS doesn't know which permissions apply to which build. User confirmed Accessibility was active for SOME entry but not the running one. |
| **M2** | Four Dicticus.app installations on disk (sizes: 23.8 MB / 39 MB / 31.8 MB / 93.6 MB) at different paths | **19.7** | Build script must install to canonical `/Applications/Dicticus.app` and remove stale copies. Provide a one-liner uninstaller for dev cleanup. |
| **M3** | When permissions are missing, the app gives no in-app indication — user has to dig into System Settings to discover | **19.7** | Menu-bar dropdown should show a permission-status row (Microphone, Accessibility, Input Monitoring) with a "Repair" button when any are missing. Use `AXIsProcessTrusted()` for Accessibility, `IOHIDCheckAccess()` for Input Monitoring. |

## Strategic Decisions (locked during UAT discussion)

| ID | Decision | Owner | Rationale |
|----|----------|-------|-----------|
| **S1** | **Swiss German Spelling defaults ON.** Manual override allowed. **NO geolocation-based detection.** | 19.5 | User is Swiss; CH-locale users are a primary segment. Auto-detect via Standortdaten was rejected as privacy-invasive and locale-data is unreliable. |
| **S2** | (Confirmed expected behavior, not a bug) Swiss toggle alone improves output even without LLM — that's `applySwissITN` running deterministically pre-LLM | — | D-15 working as designed. No action. |
| **S3** | **One DESIGN.md** for the whole project (not per-platform) | DESIGN.md | iOS + macOS share Apple-HIG idioms; brand tokens are platform-independent. Windows divergence is small and a §5 section suffices. Re-evaluate if Windows expands. |
| **S4** | Currency/number formatting handled by **Apple `Locale("de_CH")` + `NumberFormatter`** (CLDR-backed), NOT a third-party Swiss German library | 19.5 | Per Swiss-German research: native API produces `1'250` and `CHF 15.50` correctly. LanguageTool is 200 MB JVM (reference only); Hunspell de_CH is GPL (license-incompatible). |
| **S5** | Helvetism preservation in LLM cleanup via curated **~30-item word list** in the prompt (Velo, Trottoir, parkieren, Billett, Cervelat…) sourced from Wikipedia "Liste von Helvetismen" (CC BY-SA, attribution required) | 19.5 | No usable open-source library exists. Curate manually, attribute, easy to extend. |
| **S6** | Bundeskanzlei *Schreibweisungen* PDF as source-of-truth for written-Swiss-Standard-German style rules when extending STYLE prompt | 19.5 | Official Swiss Federal Chancellery style guide, freely available. |

## Sequencing

```
1. DESIGN.md          (next — invoking /design-md)
2. 19.7 macOS Hygiene (parallel-able with 19.5; high priority — unblocks daily macOS use)
3. 19.5 CH-Determinism (small, deterministic, ships fast; integrates B2 hotfix)
4. 19.6 iOS UX        (depends on DESIGN.md tokens)
5. Final UAT pass on Phase 19 (combined 19.5+19.6 sign-off)
```

## Reference Inputs

- `/Users/mowehr/code/dicticus/.planning/research/swiss-german-linguistic-resources.md` — full Swiss-German research (~210 lines)
- `/Users/mowehr/code/dicticus/.planning/phases/19-ai-cleanup-ios/19-UAT-CATALOG.md` — original UAT exit-gate catalog (the test plan we ran)
- `/Users/mowehr/code/dicticus/Shared/Utilities/ITNUtility.swift` — `applySwissITN` (extension point for B4)
- `/Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift` — STYLE prompt (extension point for S5/S6)
- `/Users/mowehr/code/dicticus/iOS/Dicticus/Services/IOSModelDownloadService.swift` — pattern for any new Parakeet cache fix
- `/Users/mowehr/code/dicticus/macOS/Dicticus/Services/HotkeyService.swift` (or equivalent — verify path) — extension point for M1
