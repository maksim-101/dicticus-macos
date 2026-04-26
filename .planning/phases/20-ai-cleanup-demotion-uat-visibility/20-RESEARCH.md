# Phase 20: AI Cleanup Demotion + UAT Visibility — Research

**Researched:** 2026-04-26
**Domain:** Swift 6 / SwiftUI / llama.cpp Metal / GRDB+SQLite / on-device ASR-cleanup pipeline (cross-platform macOS 15 + iOS 18)
**Confidence:** HIGH (most claims verified against in-repo code; LLM-pipeline literature CITED; one ASSUMED area: filler word list curation needs UAT validation)

## Summary

Phase 20 demotes Gemma 4 from authoritative rewriter to optional polish, moves filler / currency-fold / self-correction into deterministic Swift, exposes raw vs polished output in iOS history, and replaces the `fatalError` at `Shared/Services/HistoryService.swift:61` with a per-app fallback container. Every change must ship on macOS and iOS together (cross-platform parity convention).

The good news: every C-level dependency is already in place. `llama_sampler_init_temp(0.1)` is a one-line change in `CleanupService.swift:123` (the existing chain already uses temp `0.2` — we lower it to `0.1`). The llama.cpp xcframework bundled via `mattt/llama.swift` v2.8833.0 also exposes `llama_sampler_init_greedy()` for an even harder lock if temp 0.1 still wanders. Levenshtein is a ~30-line pure-Swift function — no dependency. The iOS history detail view fits the standard `NavigationStack` + `navigationDestination(for:)` pattern. The HistoryService fallback is a textbook `containerURL(...) ?? applicationSupportDirectory` substitution.

The hard parts are (1) calibrating the Levenshtein threshold so that legitimate cleanup edits pass while hallucinations fail, (2) writing filler-word and self-correction lists that don't strip semantically meaningful tokens (e.g., `also` as "therefore" in German, `I mean it` keeping "it"), and (3) preserving idempotency between the existing `SwissNumberFormatter` cross-token bridge and the new currency-fold rule. All three are addressable with fixture-driven TDD, but they need conservative thresholds and explicit corpus-based test cases.

**Primary recommendation:** Build a single new `Shared/Services/RulesCleanupService.swift` that owns filler removal, self-correction, and currency-fold (in that order, before the LLM gate). Wire it as Step 2c of `TextProcessingService.process(...)` between the existing Swiss ITN and the optional LLM call. Compute Levenshtein normalized distance over the rules-cleaned text vs the LLM output; if `dist > 0.30`, discard the LLM output. Use `llama_sampler_init_temp(0.1)` plus a deterministic seed for reproducibility. Build the iOS detail view as `HistoryDetailView` reachable via `NavigationLink(value: entry)` from `HistoryRow`, with a per-row segmented control toggling raw/polished and a UserDefaults-backed default. Replace the `fatalError` in HistoryService with a `try-or-fallback` chain that warns once via `os.Logger`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deterministic cleanup rules (filler, self-correction, currency-fold) | Shared/ Swift services | — | Cross-platform parity; tested with fixtures; never sent to LLM |
| LLM sampling configuration | Shared/Services/CleanupService.swift | — | One sampler chain rebuilt per app; single source of truth |
| Levenshtein verification gate | Shared/Utilities (new) | CleanupService call site | Pure function; testable in isolation |
| Pipeline orchestration (rules → LLM → swiss-format) | Shared/Services/TextProcessingService.swift | — | Existing orchestrator; this phase adds Step 2c |
| Raw/polished UI toggle (per row + global default) | iOS Views + macOS Views | UserDefaults | UI-tier; reads existing `text` and `rawText` columns |
| History detail view (iOS) | iOS/Dicticus/History/HistoryDetailView.swift (new) | — | iOS-only file; macOS already has detailed list |
| App Group fallback (HistoryService init) | Shared/Services/HistoryService.swift | os.Logger | Storage tier; logged once, surfaced to Settings |

<phase_requirements>
## Phase Requirements

The CONTEXT.md notes "Requirements: None directly — follow-on from Phase 19.5 UAT findings." There are no requirement IDs in REQUIREMENTS.md for this phase. The driver is the UAT findings inventory at `.planning/phases/19-ai-cleanup-ios/19-UAT-FINDINGS.md`. Treat the four LOCKED Actions in CONTEXT.md as the requirement set:

| Pseudo-ID | Description | Research Support |
|-----------|-------------|------------------|
| ACT-1-LLM-REIN | Lower Gemma temperature, change prompt verb, add Levenshtein verification gate | llama.cpp sampler API + Levenshtein implementation (sections below) |
| ACT-2-RULES | Filler removal, currency-fold, self-correction in Shared/ Swift | Filler lists + repair-pattern literature (sections below) |
| ACT-3-VISIBILITY | iOS history detail view with raw/polished toggle | SwiftUI NavigationStack pattern (section below) |
| ACT-4-RESILIENCE | Replace `HistoryService.swift:61` fatalError with per-app fallback | FileManager + os.Logger pattern (section below) |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Strategy — Option C (Hybrid)**
- LLM is demoted from "authoritative rewriter" to "optional polish layer." The deterministic Swift pipeline is the primary path; LLM output is opt-in and Levenshtein-gated.
- Cross-platform parity — every change ships on macOS and iOS together (per `feedback_cleanup_cross_platform_parity` memory).
- Industry alignment — pattern matches Superwhisper's documented architecture (rules-first deterministic + LLM-optional).

**Action 1 — Rein in the LLM**
- Lower Gemma 4 inference temperature from current default to **0.1** (or equivalent low-creativity setting).
- Replace prompt verb "Rewrite" with **"Lightly edit"** in `CleanupPrompt.defaultInstruction`. Same for any per-language variants.
- Add **Levenshtein verification gate**: after the LLM returns, compare normalized-Levenshtein distance between LLM output and the rules-cleaned input. If distance exceeds a threshold (target ~30%), discard the LLM output and use the rules-cleaned text instead.
- The user-customizable instruction (UserDefaults `cleanupInstruction`) keeps its existing override path; the *default* instruction text changes only.

**Action 2 — Move deterministic cleanup into Swift**
- Filler-word removal moves from LLM responsibility to Swift (e.g. "äh", "ähm", "um", "uh", "halt", "also" — exact list TBD during planning, gated by language).
- Currency-fold rule: `"X Franken Y Rappen"` collapses to `"CHF X.Y0"` (and analogous EUR/Cent fold). This complements — not replaces — the existing `SwissNumberFormatter` cross-token bridge for split cents (B3-original).
- Self-correction handling: when the speaker says "ich meine Y" (or English "I mean Y") immediately after token X, drop X and keep Y. Specific connectors TBD ("ich meine", "I mean", "genauer gesagt", "rather", "or rather"). Bounded by safe windows (max N preceding tokens).
- All of these live in `Shared/Services/`. `TextProcessingService` orchestrates: rules pass → optional LLM pass → SwissNumberFormatter post-pass.

**Action 3 — Visibility**
- iOS history detail view exposes both raw and polished text for the same entry. The `text` and `rawText` columns are already populated by Phase 19 (D-38).
- Cross-platform raw/polished toggle: a per-entry control (and/or global default) lets the user choose which version is copied to the clipboard. Default is **Raw** until UAT confirms LLM trust.
- The toggle's exact UI shape is a planning concern — but the data plumbing is already in place via the GRDB schema.

**Action 4 — HistoryService graceful degradation**
- Replace `fatalError("App Group container not found")` at `Shared/Services/HistoryService.swift:61` with a per-app fallback container path (e.g. `FileManager.default.urls(for: .applicationSupportDirectory, ...)`).
- Log the missing-App-Group condition once via `os.Logger` (warn-level), and surface a non-blocking warning state the iOS Settings UI can read for diagnostics.
- History writes in fallback mode are *not* shared with future keyboard extensions; that is acceptable degradation.

### Claude's Discretion

- Exact Levenshtein threshold value (start ~30%, tune during planning/execution).
- Exact filler-word lists per language.
- Exact connector pattern list for self-correction handling.
- File-decomposition (one new `Shared/Services/RulesCleanupService.swift` vs. extension methods on existing `TextProcessingService`).
- UI shape of raw/polished toggle (planning will propose, then verify against design conventions in code).
- Test split (unit fixtures for each rule, integration for pipeline order, snapshot for history detail view).

### Deferred Ideas (OUT OF SCOPE)

- Phase 19.6 — iOS UX polish (dynamic home screen, bigger mic icon, scrollable dictation pane, auto-stop, search-match highlight) — blocked on DESIGN.md, separate phase.
- Replacing Gemma with a larger/different LLM — out of scope; this phase reframes the LLM, not retrains the choice.
- ASR-side improvements (acronym spacing collapse, Parakeet swap) — different layer, separate roadmap items.
- Background download of GGUF model on iOS — accepted scope deferral from Phase 19 (D-35).
- iCloud Sync (Phase 18) — explicitly deferred at milestone level.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- **Cross-platform parity (memory):** Every cleanup pipeline change ships macOS + iOS together. All Action-2 rules MUST live in `Shared/`. [VERIFIED: project memory `feedback_cleanup_cross_platform_parity`]
- **Privacy:** No audio or text leaves the device. All rules and Levenshtein gate run locally; no telemetry. [VERIFIED: CLAUDE.md "Privacy" hard constraint]
- **Performance:** Total cleanup latency target ~4 s on iOS, ~5 s on macOS. New rules pass + Levenshtein add cost; budget ≤ 50 ms for pure-Swift preprocessing. [VERIFIED: existing `inferenceTimeoutSeconds` 8.0 (iOS) / 5.0 (macOS) in CleanupService.swift:64-65]
- **GSD workflow:** All edits go through a GSD command (project CLAUDE.md). Phase 20 plan tasks must execute via `/gsd-execute-phase`.
- **Test convention:** Fixtures live in `iOS/DicticusTests/Fixtures/` as JSON (existing pattern: `CurrencyAntiFlip.fixtures.json`, `SwissNumberFormatter.fixtures.json`, `SwissGerman.fixtures.json`). [VERIFIED: ls iOS/DicticusTests/Fixtures]

## Pipeline architecture (current vs target)

### Current (Phase 19.5, post-hotfix)

```
ASR raw text
    │
    ▼
Step 1: DictionaryService.apply         (find-and-replace from user dict)
    │
    ▼
Step 2: ITNUtility.applyITN             (German/English number words → digits)
    │
    ▼
Step 2b: ITNUtility.applySwissITN       (ß → ss, gated on useSwissGerman)
    │
    ▼
Step 3: cleanupService.cleanup          (LLM, gated on mode == .aiCleanup)
        │
        ├─ snapshot useSwissGerman
        ├─ build CleanupPrompt (Helvetisms + STRICT-currency)
        ├─ llama_decode + sample loop (temp 0.2, top_k 40, top_p 0.9)
        ├─ stripPreamble  (chat-template + boilerplate)
        ├─ CurrencyAntiFlip.revertCurrencyFlip  (de only)
        └─ ITNUtility.applySwissITN  (post-LLM safety net)
    │
    ▼
Step 3b: SwissNumberFormatter.format    (gated on useSwissGerman)
    │
    ▼
Step 4: HistoryService.save  (text=processed, rawText=raw)
```

[VERIFIED: Read of `Shared/Services/TextProcessingService.swift` lines 28-85 and `Shared/Services/CleanupService.swift` lines 153-264.]

### Target (Phase 20)

```
ASR raw text
    │
    ▼
Step 1: DictionaryService.apply
    │
    ▼
Step 2: ITNUtility.applyITN
    │
    ▼
Step 2b: ITNUtility.applySwissITN
    │
    ▼
Step 2c (NEW): RulesCleanupService.apply        ← cross-platform deterministic
        │
        ├─ removeFillers(language)              ("äh", "ähm", "um", "uh", … gated)
        ├─ resolveSelfCorrection(language)      ("X, ich meine Y" → "Y")
        ├─ foldCurrency()                       ("X Franken Y Rappen" → "CHF X.Y0")
        └─ collapseWhitespace
    │
    ▼  rulesCleanedText  ── snapshot for Levenshtein gate
    │
    ▼
Step 3: cleanupService.cleanup                  (LLM, gated on mode == .aiCleanup)
        │
        ├─ build prompt with NEW verb "Lightly edit"
        ├─ sampler chain temp = 0.1  (was 0.2)
        ├─ stripPreamble
        ├─ LEVENSHTEIN GATE (NEW):
        │     normalizedDist(rulesCleanedText, llmOutput) > threshold (~0.30)?
        │       YES → discard llmOutput, return rulesCleanedText
        │       NO  → keep llmOutput
        ├─ CurrencyAntiFlip.revertCurrencyFlip
        └─ applySwissITN
    │
    ▼
Step 3b: SwissNumberFormatter.format
    │
    ▼
Step 4: HistoryService.save  (text=processed, rawText=raw, mode=mode)
```

**Key invariants:**
- The existing `SwissNumberFormatter` cross-token bridges (B3 split-cents and Bridge-1 decimal) MUST run AFTER the new `foldCurrency()` rule. The new rule produces canonical `"CHF 110.90"` form which is already-Swiss; the formatter is idempotent on already-formatted Swiss numbers (verified by `bridgeCrossTokenDecimal` regex `(?<![.,'\u{2019}])` lookbehind in `SwissNumberFormatter.swift:101`). [VERIFIED: read of SwissNumberFormatter.swift lines 85-109]
- Levenshtein gate compares against the *rules-cleaned* text, NOT the raw ASR text. This is the key insight: if the rules pass already produced acceptable output, the LLM is only allowed minor polish (punctuation, casing).
- Idempotency: every rule must be safely re-runnable. We rely on this for the post-LLM Swiss safety net to remain intact.

## LLM sampling / temperature in LlamaSwift

### What the bundled llama.cpp exposes

The macOS Xcode project pins `mattt/llama.swift` at version `2.8833.0` (revision `2b0eb53b...`). [VERIFIED: `macOS/Dicticus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`]

The xcframework bundles a recent llama.cpp build with these C-level samplers callable from Swift via the `LlamaSwift` import. Confirmed signatures from `llama.h` in the framework:

```c
LLAMA_API struct llama_sampler * llama_sampler_init_greedy(void);
LLAMA_API struct llama_sampler * llama_sampler_init_dist(uint32_t seed);
LLAMA_API struct llama_sampler * llama_sampler_init_top_k      (int32_t k);
LLAMA_API struct llama_sampler * llama_sampler_init_top_p      (float p, size_t min_keep);
LLAMA_API struct llama_sampler * llama_sampler_init_min_p      (float p, size_t min_keep);
LLAMA_API struct llama_sampler * llama_sampler_init_temp       (float t);
LLAMA_API struct llama_sampler * llama_sampler_init_temp_ext   (float t, float delta, float exponent);
```

[VERIFIED: grep of `macOS/build/SourcePackages/artifacts/llama.swift/llama-cpp/llama.xcframework/.../llama.h`]

### What CleanupService.swift currently does

Lines 119-130 build a sampler chain:

```swift
let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.2))
llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
self.sampler = samplerChain
```

[VERIFIED: Read CleanupService.swift:119-130]

### Recommended change (Action 1)

Two viable variants — pick one in planning. Both honor CONTEXT.md's "0.1 (or equivalent low-creativity setting)":

**Variant A — Conservative (recommended):**
```swift
llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.1))    // 0.2 → 0.1
llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(/* fixed seed for reproducibility */ 42))
```

Why fixed seed: `UInt32.random(...)` produces a different seed each call, which means even if the model lands on the same logits, the sampled token can differ across two identical inputs. With temp 0.1 the distribution is sharply peaked, but a fixed seed makes UAT regressions reproducible.

**Variant B — Hard lock (simpler):**
```swift
llama_sampler_chain_add(samplerChain, llama_sampler_init_greedy())
```

Greedy sampling always picks the argmax. Equivalent to `temp=0, top_k=1` and is fully deterministic. [CITED: https://deepwiki.com/ggml-org/llama.cpp/3.7-token-sampling-and-generation — "At temperature 0, llama.cpp uses greedy decoding, which always selects the highest probability token and is fully deterministic."]

The trade-off: greedy can produce repetitive output on long sequences. For dictation cleanup (typically ≤ 200 tokens output) this is fine. CONTEXT.md says "0.1 or equivalent" so either works.

**Recommendation:** Start with Variant A (temp 0.1 + fixed seed). It keeps the existing chain shape, lowers temp to the locked value, and adds reproducibility. Variant B is the fallback if UAT shows temp 0.1 still wanders.

### Pitfall — `llama_sampler_init_dist` placement

The chain order matters: temp/top_k/top_p reshape the distribution; the *final* sampler in the chain (`dist` or `greedy`) actually picks a token. Do NOT replace `dist` with `greedy` AND keep `temp`/`top_k`/`top_p` — the upstream filters become no-ops because greedy ignores the distribution shape and just argmaxes the logits. If you go Variant B, drop the temp/top_k/top_p adds.

[CITED: https://github.com/ggml-org/llama.cpp/discussions/3005 — "if you set temp <= 0.0f and keep the default samplers, you are still getting a deterministic result, though it might not be the token with the highest logit."]

## Levenshtein in Swift — implementation + threshold

### Implementation (pure Swift, no dependency)

Standard DP with two-row optimization. Operates on `[Character]` to handle Unicode grapheme clusters correctly:

```swift
/// Edit distance between two strings, in O(m·n) time and O(min(m,n)) space.
/// Operates on Character (extended grapheme clusters) so "é" (one composed
/// scalar) and "é" (e + combining acute) both count as one character match
/// when normalized.
public enum LevenshteinDistance {
    public static func distance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,            // deletion
                    curr[j - 1] + 1,        // insertion
                    prev[j - 1] + cost      // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }

    /// Normalized distance in [0.0, 1.0]. Returns 0.0 when both strings are empty.
    public static func normalizedDistance(_ s1: String, _ s2: String) -> Double {
        let d = distance(s1, s2)
        let denom = max(s1.count, s2.count)
        return denom == 0 ? 0.0 : Double(d) / Double(denom)
    }
}
```

[CITED: https://gist.github.com/bgreenlee/52d93a1d8fa1b8c1f38b — Swift gist; refined with Character-array form and two-row optimization. Also https://en.wikipedia.org/wiki/Levenshtein_distance for the matrix recurrence.]

### Normalization choice — denominator

Two common conventions:
1. `dist / max(len1, len2)` — gives values in [0,1], often called "Levenshtein ratio inverse"
2. `dist / (len1 + len2)` — gives values in [0, 0.5] for non-empty strings, common in some libraries

[CITED: https://github.com/autozimu/StringMetric.swift — uses convention 1.]

**Recommended:** `max(len1, len2)`. It's the more intuitive "what fraction changed" measure. A normalized distance of 0.30 then means "≤ 30% of the longer string changed."

### Threshold tuning

This is the most uncertain knob. Considerations:

| Scenario | Expected normalized distance |
|---------|------------------------------|
| Pure punctuation/casing fix ("hello world." → "Hello, world.") | 0.05–0.15 |
| Filler removal ("äh, das ist gut" → "das ist gut") | 0.20–0.30 |
| Light grammar fix ("ich gehe nicht zum Schule" → "ich gehe nicht zur Schule") | 0.05–0.10 |
| Hallucination ("ausgeflogen" → "ausgezogen") | 0.10–0.20 ⚠️ |
| Wholesale rewrite ("ich war im Park" → "Ich genoss einen schönen Spaziergang im Park") | 0.50+ |
| Self-correction handled twice (rules-pass + LLM also tries) | 0.30+ |

**The "ausgeflogen → ausgezogen" hallucination is the hard case.** Single-character swap inside one word produces a *low* normalized distance — Levenshtein cannot distinguish "fix grammar" from "subtle hallucination at the morpheme level." The gate is a *gross* fail-safe, not a correctness oracle.

**Recommended starting threshold:** `0.30`. This catches wholesale rewrites and large additions/deletions while letting normal cleanup edits through. Tune via fixture-driven UAT: build a corpus of (rules-cleaned, LLM-output, expected verdict) triples and adjust until precision/recall on the verdict labels stabilizes.

### Edge case — number formatting noise

If the LLM outputs `"1,250"` and the rules-cleaned text is `"1'250"`, character-level Levenshtein flags this as 1-edit distance (low ratio), good. But `"1'250.70 CHF"` vs `"CHF 1250.70"` is reordered — Levenshtein sees this as ~50% changed even though semantically identical.

**Mitigation:** normalize both sides before computing distance:
- Strip whitespace runs to single space
- Lowercase
- Strip punctuation that the rules pass might add (`,`, `.`, `'`)
- Optionally: strip currency symbols ($, €, £, CHF, EUR) since they get re-added by formatter

This is normalization for *gate purposes only*, not for output. Compute the gate over normalized strings; return the original LLM output (or the rules-cleaned text on failure).

## Filler-word lists (de + en) with rationale

### Background

The Shriberg disfluency model decomposes a disfluency into reparandum + interregnum + repair. Pure filler particles are the simplest case: an interregnum without a repair, e.g., "I went, uh, to the store." [CITED: https://aclanthology.org/P04-1005.pdf — Mark Johnson, "A TAG-based noisy channel model of speech repairs" (Brown), references Shriberg 1994.]

### German pure fillers (safe to remove)

| Word | Function | Risk | Verdict |
|------|----------|------|---------|
| `äh` / `ähm` | filled pause (canonical German um/uh) | none | REMOVE [CITED: Babbel] |
| `ehm` / `hmm` | filled pause variant | none | REMOVE |
| `ja` (sentence-initial alone) | filler/discourse marker | "ja" can also be answer "yes" — DANGEROUS | KEEP |
| `also` | sentence-initial discourse marker / filler | also means "therefore" or "so" — DANGEROUS | KEEP |
| `halt` | modal particle, no semantic content | very low — modal particle softens but rarely changes meaning | OPTIONAL (leave as toggle) |
| `eben` | modal particle | low | OPTIONAL |
| `quasi` | filler "kind of" | low | OPTIONAL |
| `genau` | "exactly" — discourse marker | "genau" can be answer "exactly" or hedge | KEEP |
| `sozusagen` | "so to speak" — filler phrase | low | OPTIONAL |

[CITED: https://www.babbel.com/en/magazine/german-filler-words; https://e-sprachlingua.com/Blog/German/filler_words.html]

**Recommendation:** ship with the conservative-safe set `{äh, ähm, ehm, hmm}`. These are unambiguously fillers in any context. Make `{halt, eben, quasi, sozusagen}` optional via a hidden flag for future tuning.

**DO NOT remove** `also`, `ja`, `genau`, `doch` — they have legitimate semantic uses and removing them silently corrupts meaning. CONTEXT.md mentions `also` as a candidate; the research view is: leave it. If users want it removed, expose it as a toggle.

### Swiss German fillers (additional)

Swiss-flavored fillers that appear in dictation when the user speaks Swiss-influenced German:

| Word | Verdict |
|------|---------|
| `hä` | filler / questioning particle. Same risk profile as English "huh" — REMOVE when standalone |
| `aso` | Swiss-German colloquial "also" — same risk as "also" — KEEP |
| `gell` | Swiss tag question "right?" — semantic — KEEP |

[ASSUMED — based on training knowledge of Swiss German conversational patterns. Not literature-verified. Recommend UAT corpus check.]

### English pure fillers

| Word | Function | Verdict |
|------|----------|---------|
| `uh` / `um` / `umm` | filled pause | REMOVE |
| `er` / `erm` | British filled pause | REMOVE |
| `like` (as discourse marker) | hedge | DANGEROUS — "I like it" must keep "like". KEEP unless user opts in |
| `you know` | discourse marker | DANGEROUS — can be a real question. KEEP |
| `I mean` | repair signal | TREAT AS SELF-CORRECTION (next section), not filler |
| `well` (sentence-initial alone) | discourse marker | risk of bleeding into substantive use ("I am well"). KEEP |
| `so` (sentence-initial alone) | discourse marker | DANGEROUS — has many uses. KEEP |
| `right` | discourse marker | DANGEROUS — semantic. KEEP |
| `okay` / `ok` | discourse marker | DANGEROUS — "is it okay?" is semantic. KEEP |

**Recommendation:** ship with `{uh, um, umm, er, erm}`. Same conservative principle: only remove unambiguous filled pauses.

### Implementation pattern

Use word-boundary regex with case-insensitive matching, scoped to language:

```swift
// Pure pseudocode — see RulesCleanupService planning task
let germanFillers = ["äh", "ähm", "ehm", "hä", "hmm"]
let englishFillers = ["uh", "um", "umm", "er", "erm"]

// Important: also strip the trailing punctuation that often follows the filler.
// Pattern matches: word boundary + filler + optional surrounding comma + space.
//   "äh, das ist gut"  → "das ist gut"
//   "Das ist, äh, gut" → "Das ist gut"
let pattern = #"(?:^|(?<=\s))(?:\b(filler1|filler2|...)\b)\s*,?\s*"#
```

**Pitfall — case sensitivity:** German fillers are usually lowercase mid-sentence but can be sentence-initial uppercase ("Äh, das ist..."). Use case-insensitive matching but preserve following sentence capitalization (i.e., re-capitalize the *next* word if you stripped a sentence-initial filler).

**Pitfall — punctuation aftermath:** "Das ist äh, gut" → naive removal → "Das ist , gut" (orphan comma). Match and consume one trailing punctuation+whitespace group as part of the filler removal.

## Self-correction patterns (de + en) with safe-window discussion

### Theory

Shriberg's reparandum-interregnum-repair structure for explicit self-correction:

```
"I want a flight to Boston, uh, I mean to Denver on Friday"
                    └reparandum──┘└interregnum┘└─repair──┘
```

[CITED: https://aclanthology.org/P04-1005.pdf]

The *interregnum* is the cue. For deterministic rule-based handling, we detect interregnum tokens and rewind a bounded number of tokens to the left to identify (and drop) the reparandum.

### Connector inventory

**German:**
| Connector | Strength | Notes |
|-----------|----------|-------|
| `ich meine` | strong | unambiguous repair signal |
| `besser gesagt` | strong | "better said" |
| `genauer gesagt` | strong | "more precisely" |
| `nein, ich meine` | strong | doubled cue |
| `oder vielmehr` | strong | "or rather" |
| `oder besser` | strong | "or better" |
| `sorry` | medium | apology often precedes repair |
| `Entschuldigung` | medium | apology |
| `oder` (alone) | DANGEROUS | "or" as conjunction is semantic |

**English:**
| Connector | Strength | Notes |
|-----------|----------|-------|
| `I mean` | strong | but BEWARE: "I mean it", "I mean what I say" — must check that `mean` is not the head verb of a clause |
| `I meant` | strong | past form |
| `or rather` | strong | unambiguous |
| `rather` (alone) | DANGEROUS | "I'd rather X" is semantic |
| `actually` | medium | sometimes repair, sometimes emphasis |
| `sorry` | medium | apology |
| `or better` | strong | |
| `scratch that` | strong | direct repair signal |
| `correction` | strong | "correction:" pattern |

### "I mean it" false-positive defense

The CONTEXT.md call-out is real: "I mean it" / "I mean what I say" has a semantic continuation, not a repair. Defense:

1. After matching `"I mean"`, peek ahead one token. If the next token is `it`, `that`, `what`, `business`, `well` — abort the rule (don't strip).
2. Or: only fire when the next token looks like a *replacement* (a noun or noun phrase, similar in shape to the candidate reparandum).

A simpler conservative defense: **only fire the rule when the connector is preceded by a comma or pause indicator**. Speech-to-text usually inserts a comma at a hesitation; deliberate "I mean it" rarely has the comma. So:

- Match `", I mean <word>"` not `" I mean <word>"`.
- This loses some recall but greatly improves precision. Acceptable for a v1 rule.

### Safe window size

How many tokens back do we drop? Literature suggests reparanda are typically 1-3 words. [CITED: https://aclanthology.org/P11-1071.pdf — empirical disfluency stats from the LDC Switchboard corpus.]

**Recommended:** start with **N=3 preceding non-stopword tokens**. If we see no clear "noun being replaced" within 3 tokens, abort the rewrite and leave the text untouched (graceful degradation — the user still sees the connector but no harm done).

### Pattern shape

```
(reparandum span)? (,)? (interregnum: connector) (,)? (repair span)
```

In a sentence like:
> "Das kostet 110 Franken, ich meine 110 Euro."

- reparandum: `110 Franken`
- interregnum: `, ich meine`
- repair: `110 Euro`
- output: `Das kostet 110 Euro.`

In a sentence like:
> "Ich gehe heute ins Kino, ich meine, mit der ganzen Familie."

- reparandum: ambiguous — there's no clear noun to replace
- repair: introduces *new* content, not a correction
- ABORT: leave text unchanged (or strip only the connector pair "ich meine,")

**Test fixture imperative:** build `RulesCleanup.fixtures.json` with at least 30 cases including BOTH true positives ("Franken, ich meine Euro") AND adversarial cases ("I mean it", "ich meine, mit der Familie"). Without this corpus the rule will overfit to the obvious cases and break on real dictation.

## Currency-fold rule design

### Spoken Swiss prices

Swiss German speakers typically dictate prices three ways:
1. `"hundertzehn Franken neunzig"` → ASR may emit `"110 Franken 90"` (3 tokens, no comma)
2. `"hundertzehn Franken neunzig Rappen"` → ASR emits `"110 Franken 90 Rappen"` (4 tokens with explicit cent unit)
3. `"hundertzehn neunzig"` → already shaped as decimal → ASR emits `"110.90"` or `"110,90"`

Phase 19.5 already handles case 1 via `SwissNumberFormatter.bridgeCrossTokenDecimal` (Bridge 2, B3 fix). [VERIFIED: SwissNumberFormatter.swift:101]

This phase needs to handle case 2 — the explicit "Rappen" / "Cent" token.

### Fold rule

```
Pattern: (\d+) (Franken|CHF) (\d{1,2}) (Rappen|Rp\.?)
   → "CHF \1.\3"  (with cents zero-padded if 1 digit)

Pattern: (\d+) (Euro|EUR|€) (\d{1,2}) (Cent|Ct\.?)
   → "EUR \1.\3"  (or "€\1.\3" — pick canonical form during planning)

Pattern: (\d+) (Dollar|USD|\$) (\d{1,2}) (Cent[s]?|Ct\.?)
   → "USD \1.\3"

Pattern: (\d+) (Pfund|Pound[s]?|GBP|£) (\d{1,2}) (Pence|p\.?)
   → "GBP \1.\3"
```

**Pad-cents rule:** if cents are 1 digit, zero-pad. `"15 Franken 5 Rappen"` → `"CHF 15.05"`. (1-digit cents are unusual but possible: "fünf Rappen" = 5 cents.)

**Test idempotency:** `"CHF 110.90"` re-runs through the rule → no match → unchanged. ✓

**Precedence:** run currency-fold BEFORE the existing `bridgeCrossTokenDecimal`. Reason: after the fold, "Franken" no longer appears, so `bridgeCrossTokenDecimal`'s Bridge-2 pattern (which looks for "<digits> <currency> <digits>") becomes a no-op for these inputs. This is the desired ordering — the fold is the higher-precision rule.

### Interaction with existing `CurrencyAntiFlip`

`CurrencyAntiFlip` runs INSIDE `CleanupService.cleanup` (post-LLM, line 240) to revert LLM currency translations. The new `foldCurrency` rule runs PRE-LLM in the rules pass. They don't overlap; both should remain.

**Verification fixture:** `"Das kostet 15 Franken 50 Rappen"` should:
1. RulesCleanup pre-pass → `"Das kostet CHF 15.50"`
2. LLM (with "Lightly edit" prompt) → ideally unchanged
3. Levenshtein gate: `0.0` distance → keep LLM (or rules) output
4. `SwissNumberFormatter.format` → idempotent → `"Das kostet CHF 15.50"`

### Edge case — currency word in non-price context

`"Das ist meine Franken-Politik"` (made up, but compound noun). The fold pattern requires `digits Franken digits` — won't match here. ✓

`"Ich habe 100 Franken in der Tasche"` (no cents). The fold pattern requires both halves — won't match. ✓ (The plain "100 Franken" passes through unchanged.)

## iOS history detail view — existing patterns + closest analog

### Current state

`iOS/Dicticus/History/HistoryView.swift` is a flat list of `HistoryRow`s with `lineLimit(3)`. Each row shows: date, language tag, truncated text, confidence, copy button. NO detail view, NO raw/polished distinction. [VERIFIED: Read iOS/Dicticus/History/HistoryView.swift]

`macOS/Dicticus/Views/HistoryView.swift` is more featureful: search, multi-select, mode tag (Plain/Cleanup), copy button. But it ALSO does not show raw text — only the polished `entry.text`. [VERIFIED: Read macOS/Dicticus/Views/HistoryView.swift]

### Recommended detail-view pattern (iOS 18 / SwiftUI)

Modern SwiftUI uses `NavigationStack` + `navigationDestination(for:)` for value-based routing:

```swift
// In HistoryView body (replacing the current ForEach):
NavigationStack {
    List {
        ForEach(historyService.entries) { entry in
            NavigationLink(value: entry) {
                HistoryRow(entry: entry)
            }
        }
        .onDelete(perform: deleteEntries)
    }
    .navigationDestination(for: TranscriptionEntry.self) { entry in
        HistoryDetailView(entry: entry)
    }
    .navigationTitle("History")
}
```

This requires `TranscriptionEntry` to conform to `Hashable`. It already does implicitly via `Identifiable + Codable` — verify during planning. If the synthesized conformance doesn't compose for the GRDB record, add an explicit `Hashable` extension keying on `uuid`.

[CITED: https://www.hackingwithswift.com/quick-start/swiftui/displaying-a-detail-screen-with-navigationlink — modern NavigationStack pattern; https://medium.com/@dinaga119/mastering-navigation-in-swiftui-the-2025-guide-to-clean-scalable-routing-bbcb6dbce929]

### `HistoryDetailView` shape

```
┌─────────────────────────────────────┐
│ ← History    [date · lang · mode]   │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │ Polished │  Raw  │  ← Picker │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ <entry.text or .rawText>    │    │
│  │   (selectable, scrollable)  │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Copy]   [Share]   [Delete]        │
└─────────────────────────────────────┘
```

Use a `Picker(_, selection:)` with `.segmented` style for the toggle. Default to `.raw` on first show (per CONTEXT.md "Default is Raw until UAT confirms LLM trust"), persisted via UserDefaults `historyDetailDefault` key.

**Selectable text:** use `Text(...).textSelection(.enabled)` so users can select substrings to copy. iOS 15+.

**Cross-platform parity:** macOS detail view should adopt the same toggle in the existing `HistoryRow` *expanded* state OR in a sheet. Simplest macOS path: extend the existing `HistoryRow` to show a small chevron disclosure that reveals raw text inline. Alternative: add the same `NavigationLink` pattern (requires the macOS HistoryView to switch from `List(selection:)` to `NavigationStack`).

**Recommendation for planning:** ship the iOS detail view as a new file `HistoryDetailView.swift` AND add a minimal raw/polished disclosure inline on macOS (expanding `HistoryRow`). This preserves macOS UX and meets cross-platform parity for the data exposure, without rewriting the macOS navigation model.

### Per-row default toggle vs global default

Two questions:
1. What does "Copy" copy by default — raw or polished?
2. Is that a global default or per-row?

**Recommended:**
- Global UserDefaults flag `historyCopyDefault` ∈ {`raw`, `polished`}. Default: `raw`.
- Per-detail-view picker overrides what the user sees. The Copy button copies what they see.
- The list-row Copy button (which doesn't show a picker) follows the global default.

This keeps the row UI minimal while letting power users drill in for control.

## HistoryService graceful degradation pattern

### Current code

```swift
private init() {
    do {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.dicticus"
        ) else {
            fatalError("App Group container not found")
        }
        let dbFolder = containerURL.appendingPathComponent("Database", isDirectory: true)
        // ...
        self.dbPool = try DatabasePool(path: dbURL.path)
        try migrate()
        load()
    } catch {
        Self.log.error("Failed to initialize database: \(error.localizedDescription)")
        fatalError("Failed to initialize History database")
    }
}
```

[VERIFIED: HistoryService.swift:58-75]

### When `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil

`containerURL(...)` returns `nil` when:
1. The App Group entitlement is missing from the build's `.entitlements` file
2. The App Group identifier in the entitlement does not match what's passed to the API
3. The provisioning profile doesn't include the App Group capability
4. (Simulator only) misconfigured signing or first-run before the simulator has provisioned the group

[CITED: https://developer.apple.com/documentation/foundation/filemanager/1412643-containerurl — Apple documentation; behavior is documented as "Returns nil if the group identifier is invalid."]

In production (App Store + correct entitlement), this returns nil only on misconfiguration — i.e., a build-time bug. In dev/simulator, it returns nil when entitlements drift between Xcode runs.

### Recommended fallback pattern

```swift
private enum StorageBackend {
    case appGroup(URL)
    case applicationSupport(URL)  // fallback — keyboard extension cannot read this
}

private static func resolveStorage(log: Logger) -> StorageBackend {
    if let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.dicticus"
    ) {
        return .appGroup(groupURL)
    }

    log.warning("App Group container not found — falling back to per-app applicationSupport. History will NOT be visible to keyboard extensions.")

    // Use applicationSupport which is guaranteed to exist for any sandboxed app.
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let bundleID = Bundle.main.bundleIdentifier ?? "com.dicticus.fallback"
    let scoped = appSupport.appendingPathComponent(bundleID, isDirectory: true)
    return .applicationSupport(scoped)
}
```

`FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first` is guaranteed to return a non-nil URL on iOS — the directory is always present in the sandbox. [CITED: https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/applicationsupportdirectory]

The directory itself may not exist on disk yet (Apple does not auto-create it for you). Always call `createDirectory(at:withIntermediateDirectories:true)` before opening the database. (The existing init already does this for `dbFolder`; preserve that call.)

### Surfacing the warning to the iOS Settings UI

CONTEXT.md says: "surface a non-blocking warning state the iOS Settings UI can read for diagnostics."

Recommended pattern: add a `@Published var storageBackend: StorageBackend` (or just a `var isUsingFallbackStorage: Bool`) to `HistoryService`, set during init. The iOS `SettingsView` can observe via `@EnvironmentObject` and display a yellow warning row:

> "History is using local app storage. This is normally fine, but transcriptions saved here will not be visible to the Dicticus keyboard extension. Reinstall the app if this is unexpected."

For macOS the same warning can appear in the `HistoryView` toolbar or settings. Or it can be omitted on macOS where App Groups are less common (the macOS app currently uses `group.com.dicticus` too — verify in planning).

### Idempotency

If the user fixes entitlements and relaunches, `containerURL(...)` returns the App Group path again. The fallback database file remains in `applicationSupport` but is not used. We do NOT migrate data from fallback → App Group automatically. CONTEXT.md says: "History writes in fallback mode are not shared with future keyboard extensions; that is acceptable degradation." So leave migration out of scope.

## Test strategy (fixtures + integration + snapshot)

### Test framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | None — Xcode-managed test target |
| Quick run command | `xcodebuild test -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DicticusTests/RulesCleanupServiceTests` |
| Full suite command | `xcodebuild test -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15'` |

[VERIFIED: existing test target structure under `iOS/DicticusTests/`]

### Phase 20 → test map

| Pseudo-Req | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACT-1-LLM-REIN | Sampler chain uses temp 0.1 (or greedy) | unit | `-only-testing:DicticusTests/CleanupServiceTests/testSamplerChainTemperature` | ❌ Wave 0 |
| ACT-1-LLM-REIN | Levenshtein normalized distance correctness | unit | `-only-testing:DicticusTests/LevenshteinDistanceTests` | ❌ Wave 0 |
| ACT-1-LLM-REIN | Gate discards LLM output when distance > threshold | integration | `-only-testing:DicticusTests/CleanupServiceTests/testLevenshteinGateRejectsHallucination` | ❌ Wave 0 |
| ACT-1-LLM-REIN | "Lightly edit" prompt verb in default instruction | unit | `-only-testing:DicticusTests/CleanupPromptTests/testDefaultInstructionUsesLightlyEdit` | partial (CleanupPromptTests exists) |
| ACT-2-RULES | Filler removal — German pure fillers | unit + fixtures | `-only-testing:DicticusTests/RulesCleanupServiceTests/testFillerRemovalGerman` | ❌ Wave 0 |
| ACT-2-RULES | Filler removal — preserves "also", "ja", "genau" | unit + fixtures | same suite | ❌ Wave 0 |
| ACT-2-RULES | Self-correction — "ich meine" replaces preceding token | unit + fixtures | `-only-testing:DicticusTests/RulesCleanupServiceTests/testSelfCorrectionGerman` | ❌ Wave 0 |
| ACT-2-RULES | Self-correction — "I mean it" preserved | unit + fixtures | same suite | ❌ Wave 0 |
| ACT-2-RULES | Currency-fold — "X Franken Y Rappen" → "CHF X.Y0" | unit + fixtures | `-only-testing:DicticusTests/RulesCleanupServiceTests/testCurrencyFoldFranken` | ❌ Wave 0 |
| ACT-2-RULES | Currency-fold idempotent on already-folded input | unit | same suite | ❌ Wave 0 |
| ACT-2-RULES | Pipeline order: rules → LLM-gate → swiss-format | integration | `-only-testing:DicticusTests/TextProcessingServiceTests/testPipelineOrder` | partial (need test) |
| ACT-3-VISIBILITY | History detail view renders raw + polished | UI snapshot | `-only-testing:DicticusUITests/HistoryDetailViewTests` | ❌ Wave 0 |
| ACT-3-VISIBILITY | Toggle persists per-row default to UserDefaults | unit | same | ❌ Wave 0 |
| ACT-3-VISIBILITY | Copy button copies the visible variant | UI | same | ❌ Wave 0 |
| ACT-4-RESILIENCE | HistoryService falls back to app support when App Group missing | unit (mocked FileManager) | `-only-testing:DicticusTests/HistoryServiceTests/testFallbackContainerWhenAppGroupNil` | partial (HistoryServiceTests exists) |
| ACT-4-RESILIENCE | Fallback warning surfaced via published property | unit | same | ❌ Wave 0 |

### Sampling rate (Nyquist validation)

- **Per task commit:** `xcodebuild test -only-testing:DicticusTests/<task-relevant-suite>` — should complete in ≤ 30 s for any single rule suite.
- **Per wave merge:** full `DicticusTests` target (all unit tests) — typically 2-3 min.
- **Phase gate:** Full suite green on both macOS and iOS before `/gsd-verify-work`. (Currently 158 macOS + parallel iOS test files; existing baseline.)

### Wave 0 gaps

- [ ] `iOS/DicticusTests/LevenshteinDistanceTests.swift` — pure-function correctness suite (empty/empty, equal/equal, single insert, single delete, single sub, full disjoint, Unicode grapheme handling, normalization formula).
- [ ] `iOS/DicticusTests/RulesCleanupServiceTests.swift` — covers filler removal, self-correction, currency-fold across de/en/Swiss German.
- [ ] `iOS/DicticusTests/Fixtures/RulesCleanup.fixtures.json` — at least 30 cases mirroring the existing `CurrencyAntiFlip.fixtures.json` shape; include adversarial "I mean it" / "auch das ist also" cases.
- [ ] `iOS/DicticusTests/CleanupServiceTests.swift` extension — `testSamplerChainTemperature`, `testLevenshteinGateRejectsHallucination` (mock the inference output via dependency injection or by extracting the gate to a pure helper).
- [ ] `iOS/DicticusUITests/HistoryDetailViewTests.swift` — snapshot test for raw/polished toggle, default state, copy behavior.
- [ ] `iOS/DicticusTests/HistoryServiceTests.swift` extension — fallback path test. May require refactoring `HistoryService.init` to accept an injectable `containerURLProvider` closure.

### Pure unit testability of the LLM-side changes

`CleanupService.cleanup` calls `runInference` which depends on real C pointers — not unit-testable. Recommendation: extract the **post-inference processing** (Levenshtein gate + currency revert + Swiss ITN) into a new pure helper, e.g.:

```swift
extension CleanupService {
    static func gateLLMOutput(
        rulesCleaned: String,
        llmOutput: String,
        threshold: Double = 0.30
    ) -> String {
        let normalized1 = normalizeForGate(rulesCleaned)
        let normalized2 = normalizeForGate(llmOutput)
        let dist = LevenshteinDistance.normalizedDistance(normalized1, normalized2)
        return dist > threshold ? rulesCleaned : llmOutput
    }
}
```

This is pure and unit-testable without llama.cpp. The integration test then verifies the orchestration in `cleanup(...)` calls the helper at the right point.

## Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | Levenshtein threshold too tight → all LLM output discarded → demoted to "always rules" silently | MEDIUM | MEDIUM | Start at 0.30; UAT-tune with fixture corpus; add metric logging (count of gate rejections per session) |
| R2 | Levenshtein threshold too loose → hallucinations like "ausgeflogen → ausgezogen" pass through | MEDIUM | HIGH | Combination with low-temp sampling (Action 1) reduces hallucination rate at source; gate is fail-safe, not primary defense |
| R3 | Filler removal strips semantically meaningful "also" / "ja" / "I mean it" | HIGH if list is wrong | HIGH (silent corruption) | Conservative initial list (`äh, ähm, uh, um` only); extensive adversarial fixtures; per-language gating |
| R4 | Self-correction false-positive on "I mean it" / "ich meine, dass…" | HIGH if pattern is greedy | HIGH (silent meaning change) | Require comma-prefix on connector; abort if no clear noun replacement candidate within window; ship with N=3 token window |
| R5 | Currency-fold conflicts with `SwissNumberFormatter.bridgeCrossTokenDecimal` Bridge-2 | LOW | LOW | Run fold BEFORE Bridge-2; verify idempotency in fixtures |
| R6 | LlamaSwift API surface differs from header — sampler chain build fails on iOS | LOW | HIGH (build failure) | API verified in xcframework headers (both tvos-arm64 and simulator slices); same headers used by existing macOS build that already calls `llama_sampler_init_temp(0.2)` |
| R7 | iOS detail view requires `TranscriptionEntry: Hashable` — may not synthesize cleanly with GRDB | LOW | LOW | Add explicit `Hashable` conformance keying on `uuid` if needed |
| R8 | App Group fallback in HistoryService skips migration → user loses prior history if entitlement breaks then re-fixes | LOW | MEDIUM | Out of scope per CONTEXT.md ("acceptable degradation"); document in release notes |
| R9 | Reproducibility regression — fixed seed makes UAT comparable but masks model variance | LOW | LOW | Document the seed choice; can revert to random for production if reproducibility not needed |
| R10 | macOS detail-view parity inflates scope — full NavigationStack rewrite of macOS HistoryView | MEDIUM | MEDIUM | Recommend inline disclosure on macOS, full detail view on iOS only — meets parity for *data exposure* without UX rewrite |
| R11 | Per-row Copy on iOS list still uses polished text by global default; users miss raw fallback | LOW | LOW | Document default in onboarding/settings; user can change via Settings |
| R12 | LLM ignores "Lightly edit" verb and rewrites anyway | MEDIUM | LOW (Levenshtein gate catches it) | Combined defense: low temp (Action 1) + verb change + gate. No single point of failure. |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode-managed) |
| Config file | None — managed by xcodegen project.yml |
| Quick run command | `xcodebuild test -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DicticusTests/<suite>` |
| Full suite command | `xcodebuild test -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15'` |

### Phase Requirements → Test Map

See "Phase 20 → test map" table above in **Test strategy** section.

### Sampling rate

- **Per task commit:** task-relevant suite (`-only-testing:DicticusTests/RulesCleanupServiceTests` or similar) — under 30 s.
- **Per wave merge:** full DicticusTests target on iOS simulator.
- **Phase gate:** full DicticusTests on iOS + macOS before `/gsd-verify-work`.

### Wave 0 gaps

- [ ] `LevenshteinDistanceTests.swift` — covers REQ ACT-1-LLM-REIN
- [ ] `RulesCleanupServiceTests.swift` — covers REQ ACT-2-RULES
- [ ] `RulesCleanup.fixtures.json` — adversarial cases for ACT-2-RULES
- [ ] `HistoryDetailViewTests.swift` (UI snapshot) — covers REQ ACT-3-VISIBILITY
- [ ] `HistoryServiceTests` extension for fallback — covers REQ ACT-4-RESILIENCE

(All paths under `iOS/DicticusTests/`. Cross-platform tests run via the macOS DicticusTests target as well — confirm both targets compile against `Shared/`.)

## State of the Art

| Old Approach (Phase 19/19.5) | Current Approach (Phase 20) | Why Changed |
|------------------------------|------------------------------|-------------|
| LLM is authoritative — owns filler removal, currency, self-correction | Rules-first deterministic; LLM optional polish | Gemma 4 E2B hallucinates and ignores in-stream self-corrections at the small-model size |
| Temperature 0.2, random seed | Temperature 0.1, fixed seed (or greedy) | Tighter creativity bound + reproducibility for UAT |
| Prompt verb "Rewrite" | Prompt verb "Lightly edit" | Standard mitigation for small-LLM over-rewriting |
| No verification gate | Levenshtein normalized-distance gate at 0.30 | Fail-safe against gross hallucinations |
| iOS history shows truncated polished text only | iOS history detail view with raw/polished toggle | UAT visibility — users need to see what cleanup changed |
| `fatalError("App Group container not found")` | Per-app fallback + warn-once log + Settings surfacing | Sim crash on misconfigured signing in dev |

## Sources

### Primary (HIGH confidence)
- `Shared/Services/CleanupService.swift` — verified sampler chain, post-process pipeline, error handling
- `Shared/Services/TextProcessingService.swift` — verified pipeline orchestration order (Steps 1, 2, 2b, 3, 3b, 4)
- `Shared/Services/HistoryService.swift` — verified the `fatalError` site (line 61) and surrounding init flow
- `Shared/Models/CleanupPrompt.swift` — verified default instruction "Rewrite", customInstructionKey override path
- `Shared/Utilities/SwissNumberFormatter.swift` — verified existing bridges and idempotency contracts
- `Shared/Utilities/ITNUtility.swift` — verified `applySwissITN` and language-gated ITN entry points
- `iOS/Dicticus/History/HistoryView.swift` — verified flat list, no detail view, `lineLimit(3)`
- `macOS/Dicticus/Views/HistoryView.swift` — verified existing pattern, search, mode tag, no raw exposure
- `macOS/build/SourcePackages/artifacts/llama.swift/llama-cpp/llama.xcframework/.../llama.h` — verified llama.cpp sampler API surface (`init_temp`, `init_greedy`, `init_dist`, etc.)
- `macOS/Dicticus.xcodeproj/.../Package.resolved` — verified `mattt/llama.swift` v2.8833.0 pin
- `.planning/phases/20-ai-cleanup-demotion-uat-visibility/20-CONTEXT.md` — locked decisions
- `.planning/STATE.md` — Phase 19.5 closure context
- `.planning/REQUIREMENTS.md` — verified no direct requirement IDs for Phase 20
- `.planning/config.json` — verified nyquist_validation: true

### Secondary (MEDIUM confidence — official docs / verified literature)
- [llama.cpp DeepWiki — Token Sampling](https://deepwiki.com/ggml-org/llama.cpp/3.7-token-sampling-and-generation) — sampler chain semantics, greedy ≡ temp=0
- [llama.cpp Discussion #3005 — Greedy Decoding](https://github.com/ggml-org/llama.cpp/discussions/3005) — top_k=1 + temp<=0 semantics
- [Apple — FileManager containerURL](https://developer.apple.com/documentation/foundation/filemanager/1412643-containerurl) — nil return semantics for App Group
- [Apple — applicationSupportDirectory](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/applicationsupportdirectory) — sandbox path guarantees
- [Hacking with Swift — NavigationLink detail screen](https://www.hackingwithswift.com/quick-start/swiftui/displaying-a-detail-screen-with-navigationlink) — NavigationStack + navigationDestination(for:) pattern
- [Wikipedia — Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance) — algorithm definition + recurrence
- [Mark Johnson — TAG-based noisy channel model of speech repairs](https://aclanthology.org/P04-1005.pdf) — Shriberg reparandum/interregnum/repair model
- [Babbel — Most Common German Filler Words](https://www.babbel.com/en/magazine/german-filler-words) — German filler classification
- [Sprachlingua — German filler words](https://e-sprachlingua.com/Blog/German/filler_words.html) — German fillers reference
- [Wikipedia — Helvetism](https://en.wikipedia.org/wiki/Helvetism) — Swiss German linguistic features
- [autozimu/StringMetric.swift](https://github.com/autozimu/StringMetric.swift) — Swift Levenshtein normalized-ratio implementation
- [bgreenlee — Levenshtein Distance in Swift gist](https://gist.github.com/bgreenlee/52d93a1d8fa1b8c1f38b) — Swift implementation reference
- [LARD — Large-scale Artificial Disfluency Generation](https://arxiv.org/pdf/2201.05041) — disfluency dataset construction
- [Disfluency Detection using Auto-Correlational Neural Networks](https://aclanthology.org/D18-1490.pdf) — disfluency detection patterns

### Tertiary (LOW confidence — assumed knowledge, recommend UAT validation)
- Swiss German conversational filler list (`hä`, `aso`, `gell`) — based on training knowledge; not literature-verified for Swiss-Standard-German dictation context
- Levenshtein threshold value 0.30 — heuristic starting point; needs corpus tuning
- Self-correction safe window N=3 tokens — heuristic; reparandum-length statistics from Switchboard suggest 1-3, not validated for German conversational dictation

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Swiss German fillers `hä, aso, gell` and their semantic risk profile | Filler-word lists | Stripping `gell` (tag question) corrupts meaning; recommend treating as KEEP unless UAT corpus shows otherwise |
| A2 | Threshold 0.30 normalized Levenshtein distance is appropriate starting point | Levenshtein | Too tight → all LLM output discarded; too loose → hallucinations slip through; needs UAT tuning |
| A3 | Reparandum window N=3 preceding tokens is appropriate for German + English dictation | Self-correction | Larger window catches more cases but increases false-positive rate; fixture-driven calibration recommended |
| A4 | `TranscriptionEntry` synthesizes `Hashable` conformance correctly given `Identifiable + Codable + FetchableRecord` | iOS detail view | If not, add explicit conformance keying on `uuid` |
| A5 | Existing `SwissNumberFormatter.format` is idempotent on outputs of new `foldCurrency` rule (i.e., `"CHF 110.90"` passes through unchanged) | Currency-fold | Verified by code-reading the Bridge-1/2 patterns — both have negative lookbehinds that exclude already-formatted Swiss numbers; high confidence but should still be a fixture test |
| A6 | macOS `HistoryService` also uses `group.com.dicticus` App Group — fallback applies symmetrically | HistoryService graceful degradation | If macOS uses a different identifier, fallback path may differ; verify in planning by reading macOS entitlements |
| A7 | "Lightly edit" prompt verb is sufficient — no other CleanupPrompt structural change is needed | LLM | If Gemma still rewrites despite verb change + temp 0.1, additional prompt anchors (e.g., "Output the input verbatim if it is already correct") may be required |
| A8 | Removing fillers "in Swift" before the LLM is strictly better than letting the LLM do it | Pipeline | If the LLM was using filler-presence as a signal for context (e.g., to know it was conversational), removing them first might subtly change LLM behavior. Mitigated by Levenshtein gate. |

## Open Questions

1. **Should the per-row Copy button on iOS list copy raw or polished by default?**
   - What we know: CONTEXT.md says "Default is Raw until UAT confirms LLM trust"
   - What's unclear: whether "Raw" applies to the global default OR per-row UI (i.e., does the per-row button always copy raw, or does it follow a global setting?)
   - Recommendation: introduce UserDefaults key `historyCopyDefault` ∈ {raw, polished}, default `raw`. The list-row Copy button reads this; the detail view's Copy button reads the picker selection.

2. **Should macOS get a full detail view or just inline disclosure?**
   - What we know: cross-platform parity for cleanup pipeline is required; UI parity is softer
   - What's unclear: whether "raw vs polished visibility" must use identical UX on both platforms or just expose the same data
   - Recommendation: iOS gets a full `HistoryDetailView` (matches iOS conventions); macOS gets an inline disclosure on `HistoryRow` (matches macOS conventions). Both expose raw + polished. Confirm during planning.

3. **What is the exact filler-word list ship list?**
   - What we know: `{äh, ähm}` (de) and `{uh, um}` (en) are unambiguous
   - What's unclear: whether `halt`, `eben`, `sozusagen` are in scope for v1
   - Recommendation: ship with the conservative-safe set only. Document the broader list as a future toggle. Re-evaluate post-UAT.

4. **What is the exact connector list for self-correction?**
   - What we know: CONTEXT.md mentions "ich meine", "I mean", "genauer gesagt", "rather", "or rather"
   - What's unclear: whether to include `actually`, `sorry`, `Entschuldigung`
   - Recommendation: ship with the strong-cue set only (`ich meine`, `besser gesagt`, `genauer gesagt`, `oder vielmehr`, `oder besser`, `I mean`, `I meant`, `or rather`, `or better`, `scratch that`). Defer ambiguous cues.

5. **Should the Levenshtein gate normalize numbers/whitespace before comparison?**
   - What we know: pure character-level Levenshtein flags `"1'250"` vs `"1,250"` as 1-edit (low ratio, fine), but flags `"1250 CHF"` vs `"CHF 1250"` as ~50% (false positive)
   - What's unclear: how often the LLM actually reorders currency-amount pairs in dictation outputs
   - Recommendation: implement a simple normalization (lowercase + collapse whitespace + strip `,` `.` `'`) in the gate. Verify with fixtures.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 26 / Swift 6 | All Swift code | ✓ | bundled | — |
| LlamaSwift (mattt/llama.swift) | CleanupService sampler change | ✓ | 2.8833.0 (pinned) | — |
| GRDB.swift | HistoryService | ✓ | already linked | — |
| llama.cpp `llama_sampler_init_greedy` | Optional Action 1 Variant B | ✓ | confirmed in xcframework headers | `llama_sampler_init_temp(0.0)` (equivalent) |
| FluidAudio | Not directly needed for this phase | ✓ | already linked | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Metadata

**Confidence breakdown:**
- Pipeline architecture: HIGH — verified by reading current code
- LLM sampling API: HIGH — confirmed via llama.h header in xcframework
- Levenshtein implementation: HIGH — standard algorithm, multiple Swift references
- Levenshtein threshold value: LOW — heuristic, needs UAT tuning (assumption A2)
- Filler-word lists (de pure / en pure): HIGH — conservative selection from cited literature
- Filler-word lists (Swiss German): LOW — assumed (assumption A1)
- Self-correction patterns: MEDIUM — Shriberg framework cited, exact connector list is judgment call
- Currency-fold rule: HIGH — pattern + idempotency verified against existing SwissNumberFormatter
- iOS detail view pattern: HIGH — modern SwiftUI standard pattern, cited
- HistoryService fallback: HIGH — Apple-documented FileManager API, well-understood pattern
- Test strategy: HIGH — mirrors existing test infrastructure

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days; llama.cpp API is stable, but iOS 18 docs may evolve)

## RESEARCH COMPLETE
