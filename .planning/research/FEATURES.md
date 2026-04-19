# Feature Landscape

**Domain:** Local dictation app (macOS menu bar) -- v1.1 new features
**Researched:** 2026-04-19
**Existing product:** Dicticus v1.0 with push-to-talk, FluidAudio/Parakeet ASR, Gemma 3 1B cleanup

## Table Stakes

Features users of dictation apps with AI cleanup expect. Missing these = product feels incomplete compared to MacWhisper, SuperWhisper, Sotto, Google Eloquent.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Cardinal number formatting (ITN) | Every serious dictation tool converts "twenty three" to "23". Parakeet TDT v3 outputs spoken form only. Users copying numbers into emails or spreadsheets need digits. | Medium | Two approaches: (1) rule-based regex in Swift pre/post-ASR, (2) add ITN instruction to LLM cleanup prompt. Recommend hybrid: rule-based for plain mode, LLM handles it in cleanup mode. See ITN section below. |
| Basic grammar/punctuation cleanup | Already shipped in v1.0. Table stakes in the market. | Done | Gemma 3 1B handles this adequately for native speakers. |
| Custom dictionary (find-replace) | SuperWhisper, Sotto, and Google Eloquent all offer this. Users with domain jargon or names that ASR consistently misrecognizes (e.g. "Claude" -> "cloud") need post-processing corrections. | Low | Simple string replacement on ASR output, applied before LLM cleanup (or independently in plain mode). See Custom Dictionary section below. |
| Transcription history | MacWhisper shows last 50 dictations with full-text search. Google Eloquent tracks all sessions with word count stats. Users want to recover text they dictated earlier without re-dictating. | Medium | Local SQLite or JSON store. No cloud sync needed. See History section below. |
| App signing and notarization | Currently requires Gatekeeper override (right-click > Open). Every legitimate Mac app is signed. Users distrust unsigned apps; IT departments may block them entirely. | Medium | Apple Developer Program ($99/yr), Developer ID certificate, notarization via `notarytool`. Not a feature per se but a distribution requirement. |
| Auto-update mechanism | Menu bar apps that require manual DMG re-download for updates get abandoned. Users expect silent or one-click updates. Sparkle is the standard for non-App Store Mac apps. | Medium | Sparkle 2 via SPM. EdDSA signing, appcast XML feed hosted on GitHub Releases. See Auto-Update section below. |

## Differentiators

Features that set Dicticus apart from competitors. Not universally expected, but high value for the target audience.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Intelligent AI cleanup for broken/non-native German | **The killer feature.** No competitor handles "almost gibberish" from non-native speakers. SuperWhisper and Sotto correct grammar but assume grammatically close input. Dicticus targets users who speak better than they write -- their spoken German has wrong prepositions, garbled word order, Swiss dialect bleed-in, and semantic near-misses (e.g. "gestanden" used instead of "gefragt", "Minischefeld" instead of "Minenfeld"). Inferring intended meaning from broken speech is a differentiator no local dictation app offers. | High | Requires model upgrade from Gemma 3 1B. See Intelligent Cleanup section below. |
| Ordinal number formatting | "am dritten April" -> "am 3. April". German ordinals use a period after the digit (3. = dritte). English uses "st/nd/rd/th". Most dictation apps skip ordinals. | Medium | Rule-based for German (digit + period), rule-based for English (digit + suffix). Can be part of the ITN rule engine. |
| Date formatting in spoken form | "dreiundzwanzigster April zweitausendsechsundzwanzig" -> "23. April 2026" (German) or "April twenty third twenty twenty six" -> "April 23, 2026" (English). | High | Requires multi-token pattern matching across German compound numbers. Defer to later version unless LLM handles it naturally. |
| Currency formatting | "dreihundert Franken" -> "300 CHF" or "twenty five dollars" -> "$25". | Medium | Rule-based with locale awareness. Swiss context means CHF/EUR not just USD. Useful but not critical for v1.1. |
| Per-language custom dictionary | Separate replacement lists for German vs English so "Cloud" -> "Claude" only applies when dictating in English (where ASR produces "Cloud" for the name), not in German where "Cloud" might be the intended word. | Low | Extend the dictionary data model with an optional language field. Minor UI addition. |

## Anti-Features

Features to explicitly NOT build in v1.1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Regex-based custom dictionary | Overkill for the use case. Users want "wrong word -> right word", not regex syntax. Regex introduces a learning curve and bug surface (invalid patterns crash at runtime). SuperWhisper's trainer supports regex for power users but Sotto keeps it simple. | Simple exact-match find-replace. Case-insensitive matching with optional whole-word toggle is sufficient. |
| Cloud-based cleanup fallback | Violates the core privacy constraint. Google Eloquent offers optional cloud mode via Gemini; Dicticus's identity is fully local. | Invest in better local model (Gemma 4 E2B) instead of cloud fallback. |
| Full NLP-based ITN pipeline (NeMo) | NeMo's nemo_text_processing package is Python/WFST-based, heavyweight, and would require a Python subprocess or bridge from Swift. Massive dependency for a problem solvable with 200 lines of Swift regex. | Rule-based Swift ITN for cardinals + ordinals. Let LLM handle edge cases in cleanup mode. |
| Transcription history cloud sync | No cloud infrastructure exists. Sync adds complexity, privacy risk, and server costs. | Local-only history. Export to file if users want portability. |
| Real-time streaming transcription display | Parakeet TDT v3 via FluidAudio is batch-mode. Adding streaming would require a different ASR architecture or chunked processing. Over-engineering for a push-to-talk tool. | Keep batch mode. Show "Transcribing..." indicator during processing. |
| Usage analytics / word-per-minute tracking | Google Eloquent offers this but it's vanity metrics for a productivity tool. Adds UI complexity for minimal value. | Skip entirely. Focus on core dictation quality. |
| Prompt customization UI for cleanup | Already have `cleanupInstruction` in UserDefaults with a default. Exposing this to users invites prompt engineering failures and support burden. | Keep the existing customizable instruction as an advanced/hidden preference. Do not surface in main UI. |
| Model auto-download on Sparkle update | Sparkle updates should not trigger multi-GB model downloads silently. | Keep model management separate from app update flow. |
| Appcast with analytics/tracking | Privacy violation for a privacy-first app. | Static appcast on GitHub Releases/Pages, no tracking. |

---

## Feature Deep Dives

### ITN (Inverse Text Normalization)

**What users expect:**

Users expect numbers to appear as digits, not words. This is the single most complained-about issue with speech-to-text tools that lack ITN. The expectation hierarchy:

1. **Cardinals (must-have):** "twenty three" -> "23", "dreiundzwanzig" -> "23"
2. **Ordinals (should-have):** "third" -> "3rd", "dritte" -> "3." (German convention: digit + period)
3. **Dates (nice-to-have):** "April twenty third" -> "April 23", "dreiundzwanzigster April" -> "23. April"
4. **Currency (nice-to-have):** "twenty five dollars" -> "$25", "dreihundert Franken" -> "300 CHF"
5. **Phone numbers (defer):** Complex formatting rules, locale-dependent, low ROI for v1.1

**Recommended approach -- hybrid:**

- **Plain dictation mode (no AI):** Apply rule-based ITN in Swift post-ASR. Swift Regex (5.7+) with RegexBuilder DSL is well-suited for deterministic number pattern matching. Build a `NumberNormalizer` service with rules for:
  - English cardinals: token-level matching ("one" -> "1", "twenty three" -> "23", etc.)
  - German cardinals: compound word decomposition ("dreiundzwanzig" -> "23", "einhundertzweiunddreissig" -> "132")
  - English ordinals: "first" -> "1st", "twenty third" -> "23rd"
  - German ordinals: "erste" -> "1.", "dreiundzwanzigste" -> "23."
- **AI cleanup mode:** Add ITN instruction to the LLM cleanup prompt: "Write all numbers as digits (e.g. 'twenty three' -> '23', 'dreiundzwanzig' -> '23'). Use German ordinal convention (3. = dritte)." The LLM handles ITN as part of its text polishing pass. This is simpler and handles edge cases (context-dependent: "one" as pronoun vs number) but less reliable with small models.
- **Execution order:** Rule-based ITN runs first on raw ASR text, LLM cleanup runs second. This means even if the LLM is slow/fails, numbers are already formatted.

**German-specific complexity:**

German compound numbers ("dreihundertzweiunddreissig" = 332) are written as single words, requiring decomposition. This is the hardest part of German ITN. A lookup table for 1-19 + tens (zwanzig, dreissig, ...) + hundreds/thousands composition covers 99% of dictated numbers. Numbers above 999,999 are vanishingly rare in dictation.

**Context sensitivity:** The word "ein" in German is both the number "one" and the indefinite article "a/an". Rule-based ITN cannot distinguish. In plain mode, default to NOT converting "ein/eine/einen" (false positive is worse than false negative). In cleanup mode, the LLM can use context.

**Confidence:** MEDIUM -- rule-based ITN for English is straightforward; German compound number decomposition needs careful implementation but is well-documented algorithmically.

### Intelligent AI Cleanup for Broken/Non-Native German

**The problem:**

The current Gemma 3 1B model is "too literal" -- it corrects surface grammar but does not infer meaning from semantically wrong words. The target audience includes non-native German speakers who:

- Use wrong prepositions ("mit einem Minischefeld" when meaning "mit einer Minenfeld-Nachricht" or similar)
- Use semantically adjacent but wrong verbs ("gestanden" [confessed] instead of "gefragt" [asked])
- Have Swiss German dialect bleed-in affecting word choice
- Produce grammatically broken but semantically recoverable sentences

This requires the model to understand *intent* behind garbled speech, not just fix grammar.

**What is achievable with small local models:**

Research findings (2025-2026):

1. **Models under 2B parameters struggle with text correction** (Hacker News consensus, academic GEC research). They tend to answer questions from the text or over-correct instead of minimally editing. Gemma 3 1B falls squarely in this category.

2. **Gemma 4 E2B (2.3B effective, 5.1B total)** is a compelling upgrade path:
   - Q4_K_M quantization: ~3.1 GB disk, ~3.5-4 GB RAM during inference
   - Outperforms Gemma 3 27B on reasoning benchmarks (AIME 2026: 37.5% vs 20.8%)
   - Already supported in llama.cpp as of April 2026
   - 128K context window (vs 32K for Gemma 3 1B) -- overkill for dictation but shows capability
   - Would fit alongside Parakeet ASR model (~1.24 GB CoreML) on a 16 GB Mac: ~1.24 GB ASR + ~4 GB LLM = ~5.2 GB, leaving ~10 GB for OS + apps

3. **Qwen 2.5 7B ranks first for German GEC** in the multilingual GEC study (LanguageTool score 0.940). However at 7B it requires ~4.5 GB at Q4 and may push memory limits with concurrent ASR.

4. **The prompt matters more than the model size** for GEC tasks. The most effective prompt is "the longest, most concrete prompt" that explicitly instructs minimal changes and preservation of correct sentences.

**Recommended approach:**

1. **Upgrade from Gemma 3 1B to Gemma 4 E2B** (Q4_K_M, ~3.1 GB). The jump from 1B to 2.3B effective parameters should meaningfully improve meaning inference. Memory budget: ~5.2 GB total (ASR + LLM) on a 16 GB Mac, comfortable.

2. **Redesign the cleanup prompt** for the non-native speaker use case:
   - Add explicit instruction: "The speaker may use wrong words that sound similar to the intended word. Infer the intended meaning from context."
   - Add examples in the prompt (few-shot): show before/after pairs of broken German -> corrected German
   - Separate "light cleanup" (grammar only, current behavior) from "deep cleanup" (meaning inference)
   - Consider a two-tier system: light cleanup uses existing prompt, deep cleanup uses enhanced prompt with few-shot examples

3. **Fallback strategy:** If Gemma 4 E2B proves insufficient for meaning inference, consider:
   - Phi-3 Mini 3.8B (Q4_K_M, ~2.2 GB) as alternative -- known for stronger reasoning
   - Gemma 4 E4B (4.5B effective, Q4_K_M ~5 GB) -- requires 8 GB+ available
   - Fine-tuning Gemma 4 E2B on German GEC data (advanced, requires training infrastructure)

**Risk assessment:**

- HIGH risk: Even with model upgrade, meaning inference from "near-gibberish" is at the frontier of what 2-3B models can do. The examples in the milestone context ("Minischefeld", "gestanden" for "gefragt") require world knowledge + phonetic similarity reasoning that small models may not have.
- MEDIUM confidence that Gemma 4 E2B will handle simple cases (wrong prepositions, word order) but LOW confidence for the hardest cases (completely wrong word requiring phonetic/semantic leap).
- Mitigation: Ship the model upgrade with improved prompts, test extensively with real non-native German speech samples, accept that some inputs will be beyond local model capability.

**Confidence:** LOW-MEDIUM -- this is the highest-risk feature. Academic research shows models under 20B struggle with correction. Gemma 4 E2B's effective 2.3B parameters may not be enough for the hardest cases, but the upgrade from 1B is worth attempting.

### Fix Cleanup Quote Injection Bug

**Problem:** The LLM wraps its output in quotation marks despite "no quotes" instructions. The current `stripPreamble` method handles `"..."` and `\u201C...\u201D` but the bug persists -- likely the model is injecting quotes mid-text or using other Unicode quote variants.

**Expected behavior:** Cleanup output is plain text with zero added quotation marks that were not in the original dictation.

**Approach:**
- Audit all Unicode quotation mark variants: `"` `\u201C` `\u201D` `'` `\u2018` `\u2019` `\u00AB` `\u00BB` `\u201E` (German opening low-9 quote)
- Compare input vs output: if output has quotes that input did not, strip them
- Add to the cleanup prompt: explicit "Never add quotation marks around the output"
- If upgrading to Gemma 4 E2B, this bug may resolve itself due to better instruction following

**Complexity:** Low
**Confidence:** HIGH -- this is a known, isolated bug with clear fix paths.

### Custom Dictionary

**What competitors offer:**

| App | Feature | Format | Per-Language | UI |
|-----|---------|--------|--------------|-----|
| SuperWhisper | Vocabulary list + replacement rules | YAML config, regex support for power users | Vocabulary hints affect all languages | Settings panel with add/remove |
| Sotto | Vocabulary hints (not replacements) | Simple word list | No | Word list with count + add button |
| Google Eloquent | Custom vocabulary from Gmail import or manual entry | Word list | No | Dictionary settings panel |
| Dragon Dictate | Vocabulary editor with training | Pronunciation + written form pairs | Per-profile | Full editor with audio training |

**Recommended approach for Dicticus:**

1. **Simple find-replace pairs** stored as JSON array in a `.json` file in Application Support:
   ```json
   [
     {"find": "cloud", "replace": "Claude", "language": null, "caseSensitive": false, "wholeWord": true},
     {"find": "Minischefeld", "replace": "Minenfeld", "language": "de", "caseSensitive": false, "wholeWord": true}
   ]
   ```

2. **Application order:** Dictionary replacements run AFTER ASR, BEFORE LLM cleanup. This means:
   - In plain mode: ASR -> ITN -> dictionary -> paste
   - In cleanup mode: ASR -> ITN -> dictionary -> LLM cleanup -> paste
   - The LLM sees pre-corrected text, improving its cleanup quality

3. **UI:** Settings panel with a table of pairs. Add/remove buttons. Optional language filter (de/en/any). Case-insensitive by default. Whole-word matching by default (prevent "cloud" from matching "cloudy").

4. **No regex.** Keep it simple. Power users can edit the JSON file directly if they want more complex patterns.

5. **Import/export:** JSON file export for backup. Low priority but trivial to implement.

**Complexity:** Low
**Confidence:** HIGH -- straightforward feature with clear prior art.

### Transcription History

**What competitors offer:**

| App | History Depth | Search | UI | Stats |
|-----|--------------|--------|-----|-------|
| MacWhisper | Last 50 dictations | Full-text search | List/grid with text previews | None |
| Google Eloquent | All sessions | Full-text search | Session list with word count | Words per minute, total words |
| SuperWhisper | All sessions | By date | Session list | None |

**Recommended approach for Dicticus:**

1. **Storage:** SQLite database in Application Support via GRDB.swift or raw SQLite C API (already available on macOS). Schema:
   - `id` (UUID), `timestamp` (Date), `rawText` (String), `cleanedText` (String?), `language` (String), `mode` (plain/cleanup), `durationMs` (Int)
   - SQLite chosen over JSON file for search performance at scale

2. **Retention:** Keep all history (no artificial limit). Offer "Clear All" and individual delete. Typical dictation is 10-200 words; 10,000 entries is under 5 MB.

3. **Search:** Full-text search via SQLite FTS5 (built into macOS). Search across both raw and cleaned text.

4. **UI:**
   - New panel accessible from menu bar dropdown or a window opened via menu item
   - List view: timestamp, language badge, first line preview, mode indicator (plain/cleanup)
   - Click to expand: show full raw + cleaned text side-by-side
   - Copy button per entry
   - Search field at top
   - Date range filter (optional, lower priority)

5. **No stats.** Words-per-minute and cumulative counts are vanity metrics. Skip.

6. **Re-use value:** Users can copy previous dictations. Also useful for debugging ASR/cleanup quality -- see what the raw ASR produced vs what cleanup changed.

**Complexity:** Medium (SQLite schema, FTS5, new UI panel)
**Confidence:** HIGH -- well-understood feature with clear patterns.

### Auto-Update via Sparkle

**What users expect from a menu bar app:**

1. Background update check (default: every 24 hours)
2. Notification when update is available (non-intrusive)
3. One-click install -- download, quit, replace binary, relaunch
4. "Check for Updates..." menu item for manual checks
5. Release notes showing what changed
6. No forced updates -- user can skip a version

**Recommended approach:**

1. **Sparkle 2** via Swift Package Manager. The standard for non-App Store Mac apps. Used by hundreds of production apps.

2. **Setup:**
   - Add `Sparkle` SPM dependency
   - Create `SPUStandardUpdaterController` in app startup
   - Add `CheckForUpdatesView` button in menu bar dropdown (under Settings or as standalone item)
   - Host appcast XML on GitHub Releases (free, reliable)
   - Sign updates with EdDSA key (Sparkle's `generate_keys` tool)
   - `generate_appcast` creates the XML + delta updates from DMG files

3. **Info.plist keys:**
   - `SUFeedURL` -- URL to appcast XML
   - `SUPublicEDKey` -- EdDSA public key for update verification
   - `SUEnableAutomaticChecks` -- true by default

4. **Release workflow:**
   - Build signed + notarized DMG
   - Run `generate_appcast` on the DMG to create appcast entry
   - Push appcast XML + DMG to GitHub Releases
   - Sparkle handles the rest

5. **Unsandboxed app consideration:** Sparkle 2 fully supports unsandboxed apps. No XPC helper needed (that's only for sandboxed apps).

**Complexity:** Medium (one-time setup, then automated per release)
**Confidence:** HIGH -- Sparkle is battle-tested, well-documented, actively maintained.

### Fix APP-03 Icon State Reactivity

**Problem:** Menu bar icon does not update to reflect transcribing/cleaning states. Recording state (mic.fill) works. Root cause: `@State` vs `@StateObject` mismatch in SwiftUI view.

**Expected behavior:** Menu bar icon transitions between 4 states:
- Idle: default icon
- Recording: pulsing microphone
- Transcribing: processing indicator
- Cleaning: processing indicator (different from transcribing, or same with label)

**Approach:** Refactor to `@StateObject` or `@ObservedObject` on the service objects that publish state changes. Standard SwiftUI reactivity pattern.

**Complexity:** Low
**Confidence:** HIGH -- well-understood SwiftUI reactivity issue.

---

## Feature Dependencies

```
App Signing + Notarization (prerequisite for auto-update)
    |
    v
Auto-Update via Sparkle (requires signed app to verify updates)

Custom Dictionary (independent, no deps)
    |
    v
ITN Rules (can share the post-processing pipeline with dictionary)

Model Upgrade to Gemma 4 E2B (independent, but enables...)
    |
    +---> Intelligent AI Cleanup (requires better model)
    |
    +---> Quote Injection Bug Fix (may resolve with better model)

Transcription History (independent, no deps)

Icon State Fix (independent, no deps)
```

## MVP Recommendation for v1.1

**Prioritize (high value, achievable):**
1. **Fix quote injection bug** -- low complexity, improves existing feature quality
2. **Fix icon state reactivity** -- low complexity, improves UX polish
3. **Custom dictionary** -- low complexity, high user value, addresses the "Claude -> cloud" problem
4. **App signing + notarization** -- prerequisite for distribution credibility and auto-update
5. **Auto-update via Sparkle** -- critical for ongoing distribution without manual DMG downloads
6. **Cardinal number ITN** -- medium complexity, high user expectation

**Attempt but accept partial success:**
7. **Model upgrade to Gemma 4 E2B + improved cleanup prompts** -- the differentiator feature. Ship the model upgrade and improved prompts. Test with real non-native German samples. Accept that the hardest cases (phonetic word substitution) may not work perfectly.

**Defer if time-constrained:**
8. **Transcription history** -- medium complexity, lower urgency than the above. Users have survived without it in v1.0. Can ship in v1.2.
9. **Ordinal/date/currency ITN** -- nice-to-have extensions of cardinal ITN. Can iterate after cardinals work.

## Sources

- [NeMo ITN documentation](https://docs.nvidia.com/nemo-framework/user-guide/24.12/nemotoolkit/nlp/text_normalization/wfst/wfst_text_normalization.html) -- German ITN support confirmed (HIGH confidence)
- [Multilingual GEC with small LLMs (2025)](https://arxiv.org/html/2505.06004v1) -- Qwen 2.5 best for German GEC, Gemma 9B best overall (MEDIUM confidence)
- [Hacker News: small LLM text correction](https://news.ycombinator.com/item?id=43511324) -- models under 20B struggle, CoEdit-XL recommended for GEC (MEDIUM confidence)
- [Gemma 4 E2B GGUF](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF) -- Q4_K_M at 3.11 GB, 2.3B effective params (HIGH confidence)
- [Gemma 4 blog post](https://huggingface.co/blog/gemma4) -- E2B outperforms Gemma 3 27B on reasoning benchmarks (HIGH confidence)
- [SuperWhisper Trainer](https://github.com/verygoodplugins/superwhisper-trainer) -- YAML-based replacement rules with regex support (MEDIUM confidence)
- [Sotto features](https://sotto.to/) -- vocabulary hints, always-on cleanup rules (MEDIUM confidence)
- [Google Eloquent](https://www.ghacks.net/2026/04/08/google-launches-ai-edge-eloquent-dictation-app-on-ios-with-offline-transcription-and-filler-word-removal/) -- history, custom vocabulary, offline ASR+cleanup (HIGH confidence)
- [MacWhisper features](https://macwhisper.helpscoutdocs.com/article/14-how-to-use-the-dictation-feature) -- history with search, last 50 dictations (MEDIUM confidence)
- [Sparkle documentation](https://sparkle-project.org/documentation/) -- SPM integration, programmatic SwiftUI setup (HIGH confidence)
- [Sparkle programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/) -- SPUStandardUpdaterController, CheckForUpdates view model (HIGH confidence)
- [itnpy2](https://pypi.org/project/itnpy2/) -- deterministic ITN approach via CSV rules (MEDIUM confidence -- Python only, validates the rule-based approach)
- [German number formation rules](https://www.germanveryeasy.com/numbers-in-german) -- compound number composition rules (HIGH confidence)
- [German ordinal rules](https://www.lingoda.com/blog/en/german-ordinal-numbers/) -- digit + period convention (HIGH confidence)
- [PolyNorm: LLM-based text normalization](https://arxiv.org/html/2511.03080v1) -- few-shot prompting for ITN (MEDIUM confidence)
- [Apple Swift Regex](https://developer.apple.com/videos/play/wwdc2022/110357/) -- RegexBuilder DSL for Swift 5.7+ (HIGH confidence)
- [Google Eloquent launch (TechCrunch)](https://techcrunch.com/2026/04/07/google-quietly-releases-an-offline-first-ai-dictation-app-on-ios/) -- new competitive entrant, offline Gemma-based (HIGH confidence)
- [Dictation app comparison 2025 (Sotto)](https://sotto.to/blog/dictation-app-comparison-2025) -- market landscape (MEDIUM confidence)
- [German GEC with LLMs (2025)](https://www.mdpi.com/2076-3417/15/5/2476) -- German children's literature GEC study (MEDIUM confidence)
