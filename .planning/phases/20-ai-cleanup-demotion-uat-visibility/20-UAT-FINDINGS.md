---
phase: 20-ai-cleanup-demotion-uat-visibility
type: uat-findings
date: 2026-04-27
tester: user (jollity.dormice05@icloud.com)
build:
  macos: /Applications/Dicticus.app installed from macOS Release build at HEAD 5ba9f9b (Phase 20.05 + test reconciliation)
  ios: built locally after iOS pbxproj regen (CleanupCopyMode + 4 new files registered, 8 references)
status: triaged-pending-20.06-plan
---

# Phase 20 UAT Findings — 2026-04-27

User-driven cross-platform UAT after Phase 20 (AI Cleanup Demotion +
Visibility) shipped. Test sentence (German, mixed-currency, mixed-locale):

> "Also dann versuchen wir es doch mal auf Deutsch. Und zwar war ich am
> vergangenen Freitag ausgeflogen. Und zwar nach Basel, war da dann
> auch auf beiden Seiten der Grenze unterwegs, das heisst also auch
> auf der deutschen und schweizerischen Seite. Und nebst vielen
> leckeren Dingen, die ich gegessen hatte, war ich natürlich auch
> einkaufen, ebenfalls auf beiden Seiten. Auf der deutschen Seite habe
> ich ca. 110.57 € ausgegeben, während ich dann später noch auf der
> Schweizerischen Seite in der Tankstelle etwas Kleines als Erfrischung
> gekauft habe. Das hat mich dann ca. 4.50 Franken gekostet."

## Test matrix observed outputs

### Configuration A — iOS, AI cleanup OFF, Swiss toggle ON
Output (good baseline — what the rules layer alone produces):

> Also dann versuchen wir es doch mal auf Deutsch. Und zwar war ich am
> vergangenen Freitag ausgeflogen. … Auf der deutschen Seite habe ich
> ca. 110.57 € ausgegeben … Das hat mich dann ca. 4.50 Franken
> gekostet.

✅ Currencies preserved. Numbers preserved. High German preserved.
This is the desired Phase 20 baseline.

### Configuration B — iOS, AI cleanup ON, Swiss toggle ON

> "Also, dann versuchen wir es doch mal **uf Dütsch**. Und zwar war
> ich am vergangene Freitag **usgfloge**. … Uf de deutsche Siite ha
> ich cirka **100.57 €**, während ich dann speter no uf de
> schwiizerische Siite i de Tankstelle öppis Chliiners als Erfrischig
> kauft ha. Das het mich dann ca. **4.50 Euro** choschtet."

❌ LLM **translated High German → Swiss German dialect**.
❌ "Franken" → "Euro" (wrong-direction currency flip).
⚠️ Number drift "110.57" → "100.57" (Gemma adjacent-digit slip).

### Configuration C — macOS, AI cleanup ON, Swiss toggle ON

> "Also dann versuchen wir es doch mal **uf Dütsch**. Und zwar war ich
> am vergangene Freitag **usgfloge** und zwar nach Basel … Ebenfalls
> uf beidne Siite uf de deutsche Siite ha ich ca. **110.57 Euro Euro**
> usgäh, während ich dann speter no uf de schwiizerische Siite i de
> Tankstelle öppis chliins als Erfrischig **chauft** ha. Das het mich
> dann cirka **4.50 Franken** choschtet."

❌ Same dialect-translation behaviour as iOS.
❌ "Euro Euro" — duplicate currency token at the 110.57 € position
   (likely the formatter folding a unit onto already-unit'd text).
✅ "4.50 Franken" preserved correctly here (asymmetric vs iOS — same
   pipeline, different outcome ⇒ non-deterministic LLM behaviour).

### Raw ASR (no rules, no LLM) — for reference

> Also, dann versuchen wir es doch mal auf Deutsch. … Auf der
> deutschen Seite habe ich circa 100,57 € ausgegeben, während ich dann
> später noch auf der Schweizerischen Seite in der Tankstelle etwas
> Kleiner als Erfrischung gekauft habe. Das hat mich dann ca. 4,50
> Euro gekostet.

⚠️ Note: raw ASR itself produced "100,57 € … 4,50 Euro" — comma decimal
+ both currencies as Euro. So the rules layer correctly fixed:
- comma → period decimal
- second mention's "Euro" → "Franken" (anti-flip working in the
  no-cleanup config)

But when AI cleanup is on, the LLM either undoes or breaks these.

---

## Findings — triaged

### F-20-UAT-01 🔴 CRITICAL — LLM translates High German → Swiss German dialect

**Symptom:** "ausgeflogen" → "usgfloge", "auf" → "uf", "Dingen" →
"Sache", "natürlich" → "natürli", "einkaufen" → "iikaufe",
"gekostet" → "choschtet" — both platforms, both Configurations B + C.

**Root cause hypothesis:** Phase 19.5's HELVETISMS prompt block in
`Shared/Models/CleanupPrompt.swift` is too broad. Gemma 4 E2B
interprets "Use Swiss spelling" as "translate to Swiss German
dialect." The Phase 20.02 verb downgrade ("Rewrite" → "Lightly edit")
did not constrain dialect rewrites because the HELVETISMS block is a
positive instruction, not a constraint.

**Why Phase 20 didn't catch this:** The Wave 1 RED tests covered
filler removal, self-correction, and currency folding. Dialect
preservation was not part of the test matrix.

**Files involved:**
- `Shared/Models/CleanupPrompt.swift` — HELVETISMS block construction
- `Shared/Utilities/SwissHelvetisms.swift` — the constants the prompt pulls in

**Goal of fix:** Swiss toggle changes orthography (ß→ss, period decimal,
"Franken" not "Euro" for CHF context) and adds Helvetism vocabulary
*only when the speaker used it* — never translates dialect.

**Likely shape of fix:**
- Reword HELVETISMS to: "Preserve the speaker's dialect register exactly.
  Only change ß→ss and decimal-comma→period. Do NOT replace High German
  words with Swiss German equivalents."
- Optionally add a NEGATIVE list ("do not change auf to uf, ausgeflogen
  to usgfloge, gekostet to choschtet, …") — small fixed set of common
  HG→CH-G traps.

---

### F-20-UAT-02 🔴 CRITICAL — Wrong-direction currency flip

**Symptom (iOS, Config B):** Speaker said "4.50 Franken" → output
"4.50 Euro". Direction is opposite of what `CurrencyAntiFlip` was
designed to fix.

**Symptom (macOS, Config C):** "110.57 €" → "110.57 Euro Euro" —
duplicate currency token glued to a string that already had €.

**Root cause hypothesis (mixed):**
- The Phase 20.03 `SwissNumberFormatter.foldCurrencyUnits` may be
  appending "Euro"/"Franken" without checking whether the value
  already carries a currency symbol/word. "110.57 €" → fold sees no
  word-form unit → appends "Euro" → result has both "€" and "Euro" →
  pipeline runs again or LLM re-folds → "Euro Euro".
- The LLM appears to assume Euro is the default currency in the second
  mention (4.50) when both were named in the same dictation —
  overriding the speaker's literal "Franken".

**Files involved:**
- `Shared/Utilities/SwissNumberFormatter.swift` — `foldCurrencyUnits`
- `Shared/Utilities/CurrencyAntiFlip.swift` — anti-flip rules
- `Shared/Models/CleanupPrompt.swift` — currency hints in prompt
- `Shared/Services/RulesCleanupService.swift` — pipeline order

**Goal of fix:** Speaker's explicit currency word ALWAYS wins. No
implicit conversion. No double-tokenization. €/CHF symbols never
appended next to existing currency words. Pipeline idempotent on
re-application.

---

### F-20-UAT-03 🟡 MEDIUM — iOS long-press on history shows path/link, not text

**Symptom:** Long-pressing a history row on iOS pops a system preview
of a path/link instead of triggering text copy or a context menu.

**Root cause hypothesis:** SwiftUI's `Text` view auto-detects URL-like
content. If `entry.text` contains anything URL-shaped (and the test
sentence doesn't, so this may also be the system long-press default),
long-press surfaces it as a link.

**Files involved:**
- `iOS/Dicticus/History/HistoryView.swift` — `HistoryRow.body`

**Likely fix:**
- `Text(entry.text).textContentType(nil)` and/or wrap in a container
  that explicitly disables auto-detection.
- Alternative: define an explicit `.contextMenu { Button("Copy") {…} }`
  on the row so long-press shows what we want, overriding the default.

---

### F-20-UAT-04 🟡 MEDIUM — iOS history truncation with no on-screen full preview

**Symptom:** Long entries show truncated to ~3 lines on the row. User
expects to be able to scroll/see full text before deciding to paste.

**Status:** Phase 20.05 *shipped* `HistoryDetailView` reachable via
NavigationLink on tap. User report suggests they did not discover the
tap (or the NavigationLink isn't firing because of gesture conflict
with F-20-UAT-03 long-press / Copy button).

**Files involved:**
- `iOS/Dicticus/History/HistoryView.swift` — verify NavigationLink
  fires; the per-row Copy button uses `.buttonStyle(.borderless)`
  which should not steal the row tap, but worth verifying.

**Likely fix:**
- Add a visible disclosure indicator (chevron) on iOS rows so the tap
  affordance is discoverable (parity with the macOS chevron added in
  20.05).
- Verify `NavigationLink(value: entry) { HistoryRow(entry: entry) }`
  doesn't lose tap to inner buttons.

---

### F-20-UAT-05 🟢 MINOR — Number drift 110.57 → 100.57 (iOS, Config B only)

**Symptom:** Gemma replaced the "1" digit with "0".

**Status:** Probably mitigated by tightening the dialect-translation
behaviour in F-20-UAT-01 — once Gemma stops rewriting words, it should
stop touching numbers too. Re-test after F-20-UAT-01 fix.

---

## What this means for Phase 20

The Phase 20 *infrastructure* shipped correctly:
- ✅ HistoryDetailView built and visible
- ✅ CleanupCopyMode + Settings rows on both platforms
- ✅ HistoryService graceful App-Group fallback
- ✅ Levenshtein gate + temp 0.1 + "Lightly edit" verb in place
- ✅ Rules-first pipeline order wired

But the *behavioural goal* of Phase 20 — "demote the LLM" — is only
half-met. The LLM is still:
- Aggressively translating dialect
- Overriding speaker-explicit currency words

The Levenshtein gate clearly isn't catching dialect-translation cases
(distance from "auf" to "uf" is 1 character per word — likely below
the 0.30 threshold even when hundreds of words are touched).

**Phase 20.06 is the corrective phase.** Scope:
1. F-20-UAT-01: HELVETISMS prompt rework (preserve dialect register)
2. F-20-UAT-02: currency-fold idempotency + speaker-explicit-currency-wins
3. F-20-UAT-03: iOS long-press → text context menu, not link preview
4. F-20-UAT-04: iOS row chevron + NavigationLink gesture verification
5. F-20-UAT-05: re-test after F-20-UAT-01 (likely no separate fix)

Phase 20 itself stays in `Code Complete (UAT-failed: behavioural)` state
in ROADMAP.md.

---

## Cross-references

- Phase 20 CONTEXT.md (.planning/phases/20-ai-cleanup-demotion-uat-visibility/20-CONTEXT.md)
- Phase 20.05 SUMMARY.md (visibility plan that surfaced this UAT)
- Phase 20 VERIFICATION.md (12/12 must-haves passed at the artifact level — finding gap was *behavioural*, not artifact-level)
- Phase 19.5 HELVETISMS source: `Shared/Utilities/SwissHelvetisms.swift`, `Shared/Models/CleanupPrompt.swift`
- Memory (auto-memory): `project_phase20_uat_findings.md` (added 2026-04-27)

## Resume notes for next session

1. Run `/gsd-plan-phase 20.06` (or `/gsd-discuss-phase` first if you want
   to consult an advisor before locking the plan).
2. Suggested phase name: **Phase 20.06 — AI Cleanup Behavioural Hotfix
   (HELVETISMS dialect preservation + currency idempotency + iOS history
   gestures)**.
3. Suggested scope: 4 findings (F-20-UAT-01 through F-20-UAT-04), with
   F-20-UAT-05 as a re-test gate, not a standalone fix.
4. Cross-platform parity rule applies: HELVETISMS prompt + currency
   formatter changes ship on iOS AND macOS together (per memory:
   feedback_cleanup_cross_platform_parity.md).
