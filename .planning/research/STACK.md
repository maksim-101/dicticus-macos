# Technology Stack: v1.1 Additions

**Project:** Dicticus v1.1 -- Cleanup Intelligence & Distribution
**Researched:** 2026-04-19
**Overall Confidence:** HIGH (most findings verified with official docs and release pages)

---

## Existing Stack (Validated in v1.0 -- DO NOT CHANGE)

| Technology | Purpose | Status |
|------------|---------|--------|
| FluidAudio 0.13.6+ | ASR via Parakeet TDT v3 on ANE | Shipped |
| llama.cpp via LlamaSwift 2.8832.0+ | LLM cleanup via Gemma 3 1B | Shipped |
| Gemma 3 1B IT QAT Q4_0 GGUF | Light AI cleanup model | Shipped |
| Swift 6 / SwiftUI / MenuBarExtra | App shell | Shipped |
| KeyboardShortcuts (sindresorhus) | Global hotkeys | Shipped |
| LaunchAtLogin-Modern | Login item | Shipped |
| AVFoundation | Audio capture | Shipped |
| NSPasteboard + CGEvent | Text injection | Shipped |
| xcodegen | Project generation | Shipped |

---

## New Stack Additions for v1.1

### 1. Inverse Text Normalization (ITN)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| LLM-based ITN (via existing Gemma 3 1B) | N/A -- prompt change only | Convert spoken numbers/dates to digits | No new dependency needed; LLM-based ITN proven to outperform rule-based WFST by 12.6% ERR (Interspeech 2024 research). Folding ITN into the existing cleanup prompt avoids adding Python, NeMo, or any external dependency. |

**Approach: Prompt-integrated ITN, not a separate system.**

The Interspeech 2024 paper "Spoken-to-written text conversion with Large Language Model" demonstrates that LLM-based ITN achieves superior results to traditional WFST-based methods, particularly in resolving ambiguity through contextual understanding. For Dicticus, this means adding ITN instructions to the existing `CleanupPrompt.defaultInstruction` rather than building a separate pipeline.

**Why NOT a separate rule-based system:**
- NVIDIA NeMo text-processing has German ITN support, but it's a Python library requiring pynini/OpenFst -- adding a Python runtime dependency to a Swift menu bar app is unacceptable for a 170 MB footprint target.
- A Swift-native rule-based ITN would need hand-written WFST grammars for German and English number systems (ordinals, cardinals, dates, times, currency, percentages) -- months of work for two languages.
- The LLM is already loaded and running for cleanup. Adding "Convert spoken numbers and dates to their written digit form" to the prompt is zero additional latency, zero additional memory, zero new code.

**For raw dictation mode (no AI cleanup):** ITN will NOT apply. Users who want raw text get raw text. ITN is inherently part of the AI cleanup pipeline.

**Prompt addition (draft):**
```
Convert spoken numbers, dates, times, and quantities to their written digit form \
(e.g., "twenty three" -> "23", "two thousand twenty four" -> "2024", \
"dreiundzwanzig" -> "23", "zweitausendfunfundzwanzig" -> "2025").
```

**Confidence:** HIGH -- approach validated by peer-reviewed research; implementation is a prompt change, not a library addition.

---

### 2. LLM Model for Intelligent Cleanup (Gibberish -> Sensible German)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Gemma 3 1B IT QAT Q4_0 (keep current) | google/gemma-3-1b-it-qat-q4_0-gguf | Primary cleanup model | Sufficient for the task with improved prompting. 1 GB disk, ~170 MB runtime when combined with ASR. |
| Gemma 4 E2B IT (future upgrade path) | google/gemma-4-E2B-it | Potential upgrade if 1B proves insufficient | 2.3B effective params, ~3.4 GB Q4, better instruction following. Only consider if testing shows Gemma 3 1B cannot handle gibberish correction. |

**Recommendation: Stay with Gemma 3 1B, improve the prompt first.**

The question of whether Gemma 3 1B can handle "gibberish -> sensible German" is fundamentally a prompt engineering question, not a model size question. The current prompt asks the model to "fix grammar, punctuation, and capitalization" -- this is too conservative for non-native speech.

**Why Gemma 3 1B is likely sufficient:**
1. The model has 140+ language support including strong German (trained on multilingual data from Gemini distillation).
2. Non-native German speech errors are predictable: wrong case endings, wrong article gender, wrong word order, missing prepositions. These are grammatical, not semantic -- exactly what a cleanup model should fix.
3. The 1B model's weakness is complex multi-step reasoning, not pattern-matching grammar fixes.
4. The research on GEC (Grammatical Error Correction) shows small models perform well when prompts are tuned for learner proficiency levels.

**Why NOT upgrade to a bigger model yet:**
- Gemma 4 E2B at Q4_K_M = ~3.4 GB disk + ~5 GB RAM. This triples the app's memory footprint from 170 MB to ~5+ GB. On 8 GB machines, this is uncomfortable.
- Phi-4 Mini (3.8B) explicitly states "not intended to support multilingual use" -- worse German than Gemma 3 1B.
- Phi-3 Mini (3.8B, from CLAUDE.md) has decent multilingual but similar size concerns and was not specifically trained for German.
- Qwen 2.5 1.5B has 29+ languages including German, but at Q4 it's ~1.1 GB and would be a lateral move from Gemma 3 1B, not an upgrade.

**Upgrade trigger:** If testing shows that Gemma 3 1B with the improved prompt cannot correct sentences like "Ich habe gestern gehen in die Laden fur kaufen Brot" -> "Ich bin gestern in den Laden gegangen, um Brot zu kaufen", then consider Gemma 4 E2B. But test the prompt first.

**If upgrade is needed, use Gemma 4 E2B IT (not Phi or Qwen):**
- Same Gemma tokenizer format, same prompt template structure, minimal code change.
- 2.3B effective parameters with PLE architecture -- better instruction following than Gemma 3 1B.
- Apache 2.0 license (same as Gemma 3).
- Already supported in llama.cpp (launched with first-day support, April 2 2026).
- Q4_K_M at ~3.4 GB is the smallest "significant upgrade" available.

**Confidence:** MEDIUM -- the sufficiency of Gemma 3 1B for gibberish correction needs empirical testing. The prompt engineering approach is HIGH confidence.

---

### 3. Prompt Engineering for Non-Native Speech Cleanup

No new library needed. This is a prompt design change in `CleanupPrompt.swift`.

**Current prompt weakness:** "Fix grammar, punctuation, and capitalization" assumes the input is mostly correct with minor errors. Non-native German can have:
- Wrong verb conjugation ("Ich gehe gestern" instead of "Ich bin gestern gegangen")
- Wrong article gender ("die Brot" instead of "das Brot")
- Wrong case ("fur den Mann" instead of "fur den Mann" -- actually correct, but wrong preposition case combos)
- Wrong word order ("Ich gestern habe gegangen in den Laden")
- Direct translations from English ("Ich bin 25 Jahre alt" is correct, but "Ich habe kalt" instead of "Mir ist kalt")
- Missing separable verb prefixes ("Ich rufe morgen an" vs "Ich rufe morgen")

**Proposed prompt strategy (two-tier):**

Tier 1 (current "light cleanup" hotkey) -- conservative:
```
Polish the following dictated text for written form.
Fix grammar, punctuation, and capitalization.
Smooth awkward spoken phrasing so the text reads fluently.
Fix speech recognition artifacts such as misrecognized filler words.
Convert spoken numbers, dates, times, and quantities to digit form.
When the speaker corrects themselves mid-sentence, keep only the final version.
Replace profanity with clean alternatives.
Keep each language exactly as spoken -- never translate.
Preserve the original meaning.
Output ONLY the polished text -- no preamble, no quotes, no explanations.
```

Tier 2 (new "intelligent cleanup" -- could be a new hotkey or a setting):
```
You are a German/English text reconstruction assistant.
The following text was dictated by a non-native speaker and may contain:
- Broken grammar, wrong word order, or incorrect verb forms
- Mixed-up articles, cases, or prepositions
- Direct translations from the speaker's native language
- Fragments or incomplete sentences
Reconstruct what the speaker most likely intended to say.
Fix all grammar to produce correct, natural-sounding text.
Convert spoken numbers, dates, and quantities to digit form.
If a sentence is ambiguous, choose the most likely intended meaning.
Output ONLY the reconstructed text -- no preamble, no quotes, no explanations.
```

**Key insight from GEC research:** The overcorrection problem. Small LLMs tend to "improve" text beyond what was intended, adding formality or changing register. The prompt must explicitly constrain the model: "Fix grammar but preserve the speaker's register and tone."

**Confidence:** MEDIUM -- prompt effectiveness needs empirical testing with real non-native dictation samples.

---

### 4. Auto-Update via Sparkle

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Sparkle | 2.9.1 (latest, March 2025) | macOS auto-update framework | De facto standard for non-App-Store macOS apps. Ed25519 signing, DMG/ZIP support, SwiftUI integration, appcast-based updates. Used by virtually every indie macOS app. |

**SPM Integration:**
```
// In project.yml packages section:
Sparkle:
  url: https://github.com/sparkle-project/Sparkle.git
  from: 2.9.1
```

**Minimum requirements:** macOS 10.11+ (Dicticus targets macOS 15, no issue). Swift Package Manager supported via binary target.

**Integration pattern for SwiftUI MenuBarExtra:**

1. Add `SPUStandardUpdaterController` as a property on the App struct.
2. Create a `CheckForUpdatesViewModel` that observes `updater.canCheckForUpdates`.
3. Add a "Check for Updates..." button in the MenuBarExtra menu.
4. Configure `SUFeedURL` in Info.plist pointing to an appcast XML on GitHub Pages or a static hosting provider.

```swift
// DicticusApp.swift addition
import Sparkle

private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

**Appcast hosting:** Use GitHub Releases + a static appcast.xml. The `generate_appcast` tool (bundled with Sparkle) creates the appcast from a directory of DMG/ZIP files and signs them with Ed25519.

**Key setup steps:**
1. Run `./bin/generate_keys` once to create an Ed25519 keypair.
2. Add the public key to Info.plist as `SUPublicEDKey`.
3. Add `SUFeedURL` to Info.plist pointing to the appcast URL.
4. Use `generate_appcast` to create signed appcast entries for each release.

**Confidence:** HIGH -- Sparkle is extremely well-documented, actively maintained (2.9.1 released March 2025), and the standard choice for macOS auto-updates.

**Source:** [Sparkle Programmatic Setup](https://sparkle-project.org/documentation/programmatic-setup/), [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)

---

### 5. Apple Developer Signing & Notarization

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Apple Developer Program | $99/year | Developer ID certificate for code signing + notarization | Required for Gatekeeper trust. Without it, users must right-click -> Open to bypass security. |
| codesign | Xcode built-in | Sign app bundle with Developer ID Application certificate | Enables hardened runtime, required for notarization. |
| xcrun notarytool | Xcode 13+ built-in | Submit to Apple's notarization service | Apple scans the binary for malware and issues a ticket. |
| xcrun stapler | Xcode built-in | Attach notarization ticket to DMG | Allows offline Gatekeeper verification without Apple server check. |
| hdiutil | macOS built-in | Create DMG distribution image | Same tool currently used, but output gets signed and notarized. |

**No new Swift dependencies.** This is entirely a build/distribution toolchain change.

**Certificates needed:**
1. **Developer ID Application** certificate -- signs the .app bundle.
2. **App-specific password** -- for notarytool authentication (generated at appleid.apple.com).

**Complete workflow:**
```bash
# 1. Sign the app (hardened runtime required for notarization)
codesign -f -s "Developer ID Application: Your Name (TEAMID)" \
  -o runtime --timestamp \
  Dicticus.app

# 2. Create DMG
hdiutil create -volname "Dicticus" -srcfolder Dicticus.app \
  -ov -format UDZO Dicticus.dmg

# 3. Sign the DMG
codesign -f -s "Developer ID Application: Your Name (TEAMID)" \
  --timestamp Dicticus.dmg

# 4. Store credentials (one-time)
xcrun notarytool store-credentials "dicticus-notary" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "APP_SPECIFIC_PASSWORD"

# 5. Submit for notarization
xcrun notarytool submit Dicticus.dmg \
  --keychain-profile "dicticus-notary" \
  --wait

# 6. Staple the ticket
xcrun stapler staple Dicticus.dmg
```

**xcodegen changes needed:**
```yaml
settings:
  base:
    CODE_SIGN_IDENTITY: "Developer ID Application"
    DEVELOPMENT_TEAM: "XXXXXXXXXX"  # Your team ID
    CODE_SIGN_STYLE: Manual  # Change from Automatic
    ENABLE_HARDENED_RUNTIME: YES  # Already set
```

**Entitlements for hardened runtime:** The app already has `com.apple.security.device.audio-input: true`. No additional entitlements needed unless llama.cpp or FluidAudio require JIT or unsigned memory (they don't -- both use Metal, which is fine under hardened runtime).

**Confidence:** HIGH -- standard Apple toolchain, well-documented workflow.

**Sources:** [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [rsms codesigning gist](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5)

---

### 6. Transcription History & Search

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| GRDB.swift | 7.10.0 (Feb 2025) | SQLite database wrapper | Swift 6 compatible (requires Swift 6.1+/Xcode 16.3+), FTS5 full-text search built-in, battle-tested, SPM native. Better than SwiftData for this use case. |

**Why GRDB over SwiftData:**
- SwiftData has higher abstraction = lower performance for text search.
- SwiftData lacks native FTS5 integration -- you'd query with predicates, not full-text search.
- GRDB gives direct SQLite FTS5 access with tokenizer control, ranked results, and prefix matching.
- Dicticus is not sandboxed and doesn't use iCloud -- SwiftData's advantages (CloudKit sync, SwiftUI bindings) don't apply.
- GRDB is a single dependency with no framework overhead. SwiftData pulls in Core Data.

**Why NOT raw SQLite (no wrapper):**
- Swift has no built-in SQLite API beyond C interop. Writing safe, Sendable database access with manual sqlite3 calls is error-prone and verbose.
- GRDB provides exactly the right abstraction: type-safe record mapping, migration support, and FTS5 pattern builders, without the overhead of an ORM.

**SPM Integration:**
```yaml
# In project.yml packages section:
GRDB:
  url: https://github.com/groue/GRDB.swift.git
  from: 7.10.0
```

**Schema design:**
```swift
// TranscriptionRecord.swift
struct TranscriptionRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var text: String           // Final output text (cleaned or raw)
    var rawText: String        // Original ASR output before cleanup
    var language: String       // "de" or "en"
    var mode: String           // "raw" or "cleanup"
    var timestamp: Date
    var durationSeconds: Float // Recording duration

    static let databaseTableName = "transcriptions"
}

// Migration
migrator.registerMigration("v1") { db in
    try db.create(table: "transcriptions") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("text", .text).notNull()
        t.column("rawText", .text).notNull()
        t.column("language", .text).notNull()
        t.column("mode", .text).notNull()
        t.column("timestamp", .datetime).notNull()
        t.column("durationSeconds", .real).notNull()
    }
    // FTS5 external content table for full-text search
    try db.create(virtualTable: "transcriptions_ft", using: FTS5()) { t in
        t.synchronize(withTable: "transcriptions")
        t.column("text")
        t.column("rawText")
    }
}
```

**Search pattern:**
```swift
// FTS5 search with ranking
let pattern = FTS5Pattern(matchingAllTokensIn: searchQuery)
let results = try TranscriptionRecord
    .joining(required: TranscriptionRecord.transcriptionsFt.matching(pattern))
    .order(Column("timestamp").desc)
    .fetchAll(db)
```

**Database location:** `~/Library/Application Support/Dicticus/history.sqlite` (matches existing model storage pattern).

**Confidence:** HIGH -- GRDB is mature (7.x, actively maintained), Swift 6 native, FTS5 support is a first-class feature.

**Sources:** [GRDB.swift GitHub](https://github.com/groue/GRDB.swift), [GRDB Full Text Search docs](https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md)

---

### 7. Custom Dictionary (Find-and-Replace)

**No new dependency needed.** This is a UserDefaults or JSON file storage feature.

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| UserDefaults / JSON file | Swift built-in | Store custom dictionary entries | Simple key-value pairs (wrong -> correct). No database needed for typically < 100 entries. |

**Implementation approach:**
- Store as `[[String: String]]` in UserDefaults (key: `customDictionary`).
- Apply as a post-processing step AFTER ASR, BEFORE AI cleanup (so the LLM sees corrected terms).
- Use case-insensitive string replacement.
- UI: simple table in settings with "ASR Output" and "Replace With" columns.

**Example entries:**
```
"cloud" -> "Claude"
"dikdikus" -> "Dicticus"
"whatsapp" -> "WhatsApp"
```

**Why apply BEFORE cleanup:** The LLM needs correct proper nouns to produce correct output. If the ASR says "cloud" but the user means "Claude", the LLM will build grammar around the wrong word.

**Confidence:** HIGH -- trivial implementation, no architectural decisions needed.

---

### 8. Quote Injection Bug Fix

**No new dependency needed.** This is a fix to the existing `CleanupService.stripPreamble()` method.

The current `stripPreamble` already strips surrounding quotes, but only handles one layer:
```swift
if (result.hasPrefix("\"") && result.hasSuffix("\"")) ...
```

The bug likely involves:
1. The LLM wrapping output in quotes that aren't stripped (different quote characters not covered).
2. The LLM injecting inline quotes within the text.
3. Quote characters surviving the sanitization pipeline.

**Fix approach:** Extend the strip logic to handle all Unicode quote variants and strip quotes more aggressively. No library needed.

**Confidence:** HIGH -- code-level fix.

---

### 9. APP-03 Icon State Reactivity Fix

**No new dependency needed.** This is a SwiftUI architecture fix.

The issue is `@State` vs `@StateObject` for service state observation. The fix is refactoring the menu bar view to use `@StateObject` or `@ObservedObject` for `TranscriptionService` and `CleanupService` state, ensuring icon changes are reactive.

**Confidence:** HIGH -- standard SwiftUI pattern fix.

---

## Complete v1.1 Dependency Additions

Only TWO new SPM packages:

| Package | URL | Version | Purpose |
|---------|-----|---------|---------|
| Sparkle | https://github.com/sparkle-project/Sparkle.git | from: 2.9.1 | Auto-update framework |
| GRDB | https://github.com/groue/GRDB.swift.git | from: 7.10.0 | SQLite + FTS5 for transcription history |

**Total new disk footprint:** Sparkle framework (~5 MB) + GRDB (~2 MB compiled). Negligible.

Everything else (ITN, intelligent cleanup, custom dictionary, bug fixes, signing) is done via prompt changes, code changes, or build configuration -- no new libraries.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| ITN | LLM prompt integration | NeMo text-processing (Python WFST) | Adds Python runtime dependency; 170 MB app would balloon. LLM-based ITN proven superior (Interspeech 2024). |
| ITN | LLM prompt integration | Swift rule-based ITN | Months of hand-written WFST grammars for de+en. Not justified when LLM is already loaded. |
| Cleanup model | Gemma 3 1B (keep current) | Gemma 4 E2B (3.4 GB Q4) | 3x memory increase for uncertain quality gain. Test prompt improvements first. |
| Cleanup model | Gemma 3 1B (keep current) | Phi-4 Mini 3.8B | "Not intended for multilingual use" -- explicitly worse German. |
| Cleanup model | Gemma 3 1B (keep current) | Qwen 2.5 1.5B | Lateral move at similar size. No proven advantage for German GEC. |
| Database | GRDB.swift | SwiftData | No FTS5 integration, higher abstraction cost, CloudKit/SwiftUI advantages irrelevant for unsandboxed menu bar app. |
| Database | GRDB.swift | Raw SQLite C API | Verbose, no type safety, no migration support, error-prone. |
| Database | GRDB.swift | SQLiteData (PointFree) | Very new (2025), built on GRDB anyway. Use GRDB directly. |
| Auto-update | Sparkle 2.9.1 | Custom update checker | Reinventing the wheel. Sparkle handles delta updates, Ed25519 signing, appcast, UI, and edge cases. |
| Custom dictionary | UserDefaults/JSON | SQLite/GRDB | < 100 entries, no search needed, no migration needed. UserDefaults is simpler. |

---

## Updated project.yml Packages Section (Complete)

```yaml
packages:
  FluidAudio:
    url: https://github.com/FluidInference/FluidAudio.git
    from: 0.13.6
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts.git
    from: 2.4.0
  LaunchAtLogin:
    url: https://github.com/sindresorhus/LaunchAtLogin-Modern.git
    from: 1.1.0
  llama:
    url: https://github.com/mattt/llama.swift.git
    from: 2.8832.0
  # --- v1.1 additions ---
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: 2.9.1
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 7.10.0
```

---

## Sources

- Sparkle 2.9.1 release: https://github.com/sparkle-project/sparkle/releases (HIGH confidence)
- Sparkle programmatic setup: https://sparkle-project.org/documentation/programmatic-setup/ (HIGH confidence)
- Sparkle publishing: https://sparkle-project.org/documentation/publishing/ (HIGH confidence)
- GRDB.swift 7.10.0: https://github.com/groue/GRDB.swift/releases (HIGH confidence)
- GRDB FTS5 docs: https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md (HIGH confidence)
- Apple notarization: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution (HIGH confidence)
- Apple Developer ID: https://developer.apple.com/developer-id/ (HIGH confidence)
- rsms codesigning reference: https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5 (HIGH confidence)
- notarytool guide: https://scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool/ (HIGH confidence)
- LLM-based ITN (Interspeech 2024): https://www.isca-archive.org/interspeech_2024/choi24_interspeech.pdf (HIGH confidence)
- NeMo ITN German support: https://docs.nvidia.com/nemo-framework/user-guide/24.12/nemotoolkit/nlp/text_normalization/wfst/wfst_text_normalization.html (MEDIUM confidence -- confirmed German listed but not tested)
- Gemma 3 1B technical report: https://arxiv.org/abs/2503.19786 (HIGH confidence)
- Gemma 4 E2B: https://huggingface.co/blog/gemma4 (HIGH confidence)
- Gemma 4 E2B GGUF: https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF (HIGH confidence -- Q4_K_M = 3.46 GB)
- Phi-4 Mini multilingual limitation: https://huggingface.co/microsoft/phi-4-gguf (HIGH confidence -- "not intended for multilingual")
- GEC prompt engineering: https://arxiv.org/html/2402.15930v1 (MEDIUM confidence)
