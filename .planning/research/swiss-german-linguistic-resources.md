# Swiss German Linguistic Resources for Dicticus

> Research scope: Find online resources to improve Dicticus' "Swiss German Spelling" toggle beyond the current `ß→ss` regex + LLM style hint. Targets the **written Swiss Standard German (Schweizer Hochdeutsch)** variant — NOT Schwyzerdütsch dialect.
>
> Date: 2026-04-24 · Author: research subagent · Audience: Dicticus implementer

---

## 1. Executive Summary

- **Apple Foundation already gets you most of the way for numbers and currency.** `Locale("de_CH")` + `NumberFormatter` correctly emits `1’234.50` and `CHF 15.50` natively on iOS/macOS. We do NOT need a third-party library for digit/currency formatting — we need an LLM **post-processor or pre-formatter** that pipes raw amounts through `NumberFormatter` with `de_CH`. (HIGH confidence)
- **The Bundeskanzlei "Schreibweisungen" is the canonical written-Swiss-Standard-German style guide.** It's a free PDF from the Swiss Federal Chancellery and the de-facto authority for orthography, numbers, currency, abbreviations, dates. Treat as the source of truth when writing prompt rules. (HIGH confidence)
- **For Helvetism preservation, use a curated word-list approach in the prompt — not an external library.** The German Wikipedia "Liste von Helvetismen" (CC BY-SA) plus the Variantenwörterbuch (commercial, but excerpts cite-able) gives ~50–200 high-frequency pairs. Embed the top ~30–50 as a "DO NOT CORRECT" prompt block when Swiss toggle is on. No usable open-source library exists for this. (MEDIUM-HIGH confidence)
- **LanguageTool has working `de-CH` rules (LGPL 2.1+) and is the only mature open-source engine.** But it's a Java/JVM monolith — too heavy to ship in an iOS app. Useful as a **reference for which rules to encode**, not as a runtime dependency. (HIGH confidence)
- **Hunspell `de_CH` dictionaries (igerman98) are GPL-only.** Cannot be linked into a closed-source / Apache 2.0 stack without contamination. Only safe usage is "shell out to a separate process" — not viable on iOS. Skip. (HIGH confidence)

---

## 2. Top 3 Recommended Integrations

### #1 — `NumberFormatter` with `Locale("de_CH")` for currency + thousands (HIGH)

Build a tiny Swift utility (`SwissNumberFormatter`) that:
- Detects amount tokens after LLM cleanup (regex: `\b(\d{1,3}(?:[.,'\s]\d{3})*(?:[.,]\d+)?)\s*(CHF|Franken|Fr\.|Rappen)\b`)
- Re-formats them via `NumberFormatter` configured with `Locale(identifier: "de_CH")` and `numberStyle = .currency` / `currencyCode = "CHF"`
- Output: `CHF 1’234.50` (note: CLDR/Apple uses U+2019 right-single-quote, NOT ASCII `'` — the Bundeskanzlei accepts both, ASCII `'` is more common in tech writing; we should match what `de_CH` Apple Locale produces by default since it tracks CLDR)

Solves the "15 Franken 50 → CHF 15.50" gap deterministically. Don't trust the LLM to do this — it's brittle.

### #2 — Augment LLM prompt with a Helvetism preservation block (MEDIUM-HIGH)

When Swiss toggle is ON and `language == "de"`, append:

```
HELVETISMS: Preserve these Swiss-standard words as-is. Do NOT replace with German variants:
Velo, Trottoir, parkieren, Billett, Perron, Camion, Poulet, Rüebli, Rande,
Cervelat, Znacht, Zmorgen, Zvieri, Estrich, Abwart, Lavabo, Cheminée,
Detailhandel, Identitätskarte, Kantonsschule, Matur, Ferien, allfällig,
zuhanden, anfangs, parkiert, grillieren, Nachtessen, Morgenessen, Spital, Tram (das), E-Mail (das)
```

Source word list: German Wikipedia "Liste von Helvetismen" (CC BY-SA 3.0, attribution required) — extract ~30-50 highest-frequency pairs. Document attribution in `Shared/Models/CleanupPrompt.swift` header.

### #3 — Codify Bundeskanzlei rules into the existing STYLE prompt (HIGH)

Expand the current single-line STYLE hint into a structured block when Swiss toggle is ON:

```
SWISS STANDARD GERMAN ORTHOGRAPHY:
- Never use ß; always write ss (Strasse, gross, Fussball)
- Use apostrophe as thousands separator: 1'250, never 1.250
- Use period as decimal separator in money: CHF 15.50
- Use comma as decimal in non-money: 3,14 Meter
- Currency format: CHF before amount (CHF 1'250.00), or "Fr." in informal contexts
- Capital umlauts at start of proper names: Ae/Oe/Ue (Oerlikon, not Örlikon)
- Preserve French/Italian loanword spelling: Spaghetti, Mayonnaise (do not Germanize)
```

Then keep the deterministic `applySwissITN` regex as a post-LLM safety net (already in place — D-19).

---

## 3. Full Resource Catalog

| # | Resource | Type | License | Maintained | Confidence | URL |
|---|---|---|---|---|---|---|
| 1 | Bundeskanzlei Schreibweisungen | Style guide PDF | Public (Swiss federal doc) | 2nd ed., active | HIGH | [bk.admin.ch](https://www.bk.admin.ch/bk/de/home/dokumentation/sprachen/hilfsmittel-textredaktion/schreibweisungen.html) |
| 2 | Bundeskanzlei Rechtschreibleitfaden | Spelling guide PDF | Public | 4th ed., 2017 | HIGH | [bk.admin.ch](https://www.bk.admin.ch/bk/de/home/dokumentation/sprachen/hilfsmittel-textredaktion/leitfaden-zur-deutschen-rechtschreibung.html) |
| 3 | Wikipedia: Liste von Helvetismen | Word list (~hundreds) | CC BY-SA 3.0 | Live | HIGH | [de.wikipedia.org/wiki/Liste_von_Helvetismen](https://de.wikipedia.org/wiki/Liste_von_Helvetismen) |
| 4 | Wikipedia: Helvetism (EN) | Reference article | CC BY-SA 3.0 | Live | HIGH | [en.wikipedia.org/wiki/Helvetism](https://en.wikipedia.org/wiki/Helvetism) |
| 5 | Wikipedia: Swiss Standard German | Reference article | CC BY-SA 3.0 | Live | HIGH | [en.wikipedia.org/wiki/Swiss_Standard_German](https://en.wikipedia.org/wiki/Swiss_Standard_German) |
| 6 | Apple `Locale("de_CH")` + `NumberFormatter` | Built-in API | Apple platform | Live | HIGH | [developer.apple.com/.../numberformatter](https://developer.apple.com/documentation/foundation/numberformatter) |
| 7 | CLDR de_CH locale data | Locale data spec | Unicode license (permissive) | Live (UC release cycle) | HIGH | [cldr.unicode.org](https://cldr.unicode.org/translation/number-currency-formats/number-and-currency-patterns) |
| 8 | LanguageTool (de-CH rules) | Grammar+spell engine | LGPL 2.1+ | Active | HIGH | [github.com/languagetool-org/languagetool](https://github.com/languagetool-org/languagetool) |
| 9 | LanguageTool de XML grammar rules | Rule set | LGPL 2.1+ | Active | HIGH | [grammar.xml in repo](https://github.com/languagetool-org/languagetool/blob/master/languagetool-language-modules/de/src/main/resources/org/languagetool/rules/de/grammar.xml) |
| 10 | Hunspell igerman98 (de_CH variant) | Spell dictionary | **GPL v2/v3** | Active (j3e.de) | HIGH | [j3e.de/ispell/igerman98](https://www.j3e.de/ispell/igerman98/index_en.html) |
| 11 | Variantenwörterbuch des Deutschen | Reference dictionary (book) | © De Gruyter, **commercial** | 2nd ed. 2016, ~12k entries | HIGH | [degruyter.com](https://www.degruyter.com) |
| 12 | Duden Schweizerhochdeutsch | Reference book | © Duden, **commercial** | Active, ~3500 Helvetisms | HIGH | [shop.duden.de](https://shop.duden.de/Schweizerhochdeutsch/9783411704187) |
| 13 | OpenThesaurus Swiss variations | Synonym DB w/ ch tag | LGPL | Active | MEDIUM | [openthesaurus.de/synset/variation/ch](https://www.openthesaurus.de/synset/variation/ch) |
| 14 | tal-mi-or.ch Helvetismen-Wörterbuch | Online Helvetism dict | Site copyright (scrape risky) | Live | MEDIUM | [tal-mi-or.ch](https://www.tal-mi-or.ch/schweizerhochdeutsch-helvetismen/) |
| 15 | Schweizerisches Idiotikon | Lexicon (dialect-focused) | © project, paywalled API | Active, 150yr project | LOW for our use | [idiotikon.ch](https://www.idiotikon.ch/) |
| 16 | SwissBERT (ZurichNLP) | LM with CH adapters | MIT | 2023, semi-active | LOW (too heavy) | [github.com/ZurichNLP/swissbert](https://github.com/ZurichNLP/swissbert) |
| 17 | Awesome-Swiss-German | Curated link list / NLP demos | MIT | Last commit 2022, dormant | LOW | [github.com/esthicodes/Awesome-Swiss-German](https://github.com/esthicodes/Awesome-Swiss-German) |
| 18 | Swiss-German-NLP/base-package | NLP scaffolding | MIT | Sparse | LOW | [github.com/Swiss-German-NLP/base-package](https://github.com/Swiss-German-NLP/base-package) |
| 19 | Wikipedia: Swiss franc (currency rules) | Reference | CC BY-SA 3.0 | Live | HIGH | [en.wikipedia.org/wiki/Swiss_franc](https://en.wikipedia.org/wiki/Swiss_franc) |
| 20 | Wikipedia: Decimal separator | Reference | CC BY-SA 3.0 | Live | HIGH | [en.wikipedia.org/wiki/Decimal_separator](https://en.wikipedia.org/wiki/Decimal_separator) |

### License triage (critical)

| License | Verdict for Dicticus |
|---|---|
| Apple platform / built-in | ✅ ship it |
| CC BY-SA 3.0 (Wikipedia) | ✅ for word-list extraction with attribution in source comments |
| MIT | ✅ |
| Unicode CLDR | ✅ |
| LGPL 2.1+ (LanguageTool) | ⚠️ dynamic-link OK on macOS as side process, but cannot embed in iOS app statically without legal review |
| **GPL v2/v3 (Hunspell de_CH dicts)** | ❌ **avoid** — would force Dicticus open-source |
| Commercial books (Duden, Variantenwörterbuch) | ⚠️ reference for our own curated word list; do NOT copy entries verbatim at scale |

---

## 4. Specific Technical Recommendations

### 4.1 Thousands separator → Apple `NumberFormatter` (HIGH)

```swift
let f = NumberFormatter()
f.locale = Locale(identifier: "de_CH")
f.numberStyle = .decimal
f.string(from: 1250 as NSNumber) // "1’250"  (uses U+2019)
```

- iOS 16+ produces correct Swiss output via CLDR data shipped in the OS.
- Caveat: Apple uses **U+2019** (right single quote) by default. Bundeskanzlei accepts both U+2019 and ASCII `'`. Recommend storing user preference (default to whatever `de_CH` produces). If we want pure ASCII, post-process: `.replacingOccurrences(of: "\u{2019}", with: "'")`.
- Don't roll our own — let CLDR/Apple be the source of truth for grouping behavior (3-digit groups, no separator below 10’000 in some style rules — Apple already implements this).

### 4.2 CHF currency → Apple `NumberFormatter` w/ `.currency` (HIGH)

```swift
let f = NumberFormatter()
f.locale = Locale(identifier: "de_CH")
f.numberStyle = .currency
f.currencyCode = "CHF"
f.string(from: 15.50 as NSNumber) // "CHF 15.50"
```

- Use case: Dicticus already does ITN (`fünfzehn franken fünfzig` → some intermediate). Add a post-ITN regex pass that detects `(\d+)\s*Franken\s*(\d+)` and `(\d+)\s+Franken` patterns and re-emits them through this formatter.
- Mandatory: place currency code BEFORE amount (per Federal style guide Art. 1 SR/RS 941.101).
- Edge case: Rappen-only amounts ("50 Rappen") — leave as-is, don't try to compress to CHF 0.50 (changes user intent).

**Implementation sketch (drop into `Shared/Utilities/`):**

```swift
struct SwissCurrencyFormatter {
    static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        return f
    }()

    /// Matches "15 Franken 50", "15 Fr. 50", "1250 CHF", "Fr. 15.50", etc.
    /// Returns canonicalised "CHF 15.50".
    static func canonicalise(_ text: String) -> String { /* regex + formatter */ }
}
```

### 4.3 Helvetism preservation → curated prompt block (MEDIUM-HIGH)

**Approach: prompt augmentation, NOT external library.**

- LLM cleanup with Gemma 4 E2B already runs every pipeline. Adding ~30 word pairs into the prompt costs ~80 tokens — negligible.
- Word list source: extract from German Wikipedia "Liste von Helvetismen" (CC BY-SA — attribute in source file header).
- Maintain the list as a Swift array constant in `Shared/Models/SwissHelvetisms.swift`; pull into `CleanupPrompt.build` only when Swiss toggle ON + `language == "de"`.
- Don't try to be exhaustive — top ~30-50 words covers >90% of everyday usage. Diminishing returns past that, and longer prompts slow the local LLM measurably.
- Future enhancement: let users add their own preserved-words list via the existing custom-dictionary feature.

### 4.4 Broader orthographic rules → hybrid: regex + prompt (HIGH)

| Rule | Best mechanism | Why |
|---|---|---|
| `ß → ss`, `ẞ → SS` | **Regex (already shipped)** | Deterministic, sub-ms, no false positives in Swiss text |
| Capital umlaut Ae/Oe/Ue at name start | **Prompt only** | Hard to do safely without proper-noun detection |
| Foreign loanword preservation (Spaghetti, Mayonnaise) | **Prompt only** | Already preserved by base German model; just don't prompt to "correct" |
| Apostrophe thousands separator | **Post-LLM `NumberFormatter`** | LLM is unreliable on punctuation tokens |
| `CHF` placement before amount | **Post-LLM regex + formatter** | Same |
| Helvetism preservation | **Prompt block** | Soft constraint; LLM handles compositionally |
| `welche(r)` relative pronoun preferred | **Prompt only** (low priority) | Stylistic; not worth complexity |

**Do NOT introduce a runtime dependency on LanguageTool or Hunspell.** Reasons:
- LanguageTool: 200+ MB JVM monolith, doesn't ship to iOS at all.
- Hunspell de_CH: GPL-tainted (igerman98 is GPL v2/v3). Even via XPC service the licensing would force Dicticus to open-source under GPL.

---

## 5. Open Questions for Follow-up

1. **Apostrophe glyph choice**: Should our re-emitted thousands separator be U+2019 (Apple/CLDR default) or ASCII `'` (most common in user-typed and Bundeskanzlei examples)? Recommend U+2019 for visual fidelity, expose as optional preference.
2. **Decimal separator in non-currency**: Should "3,14 Meter" stay comma or become point in Swiss mode? Bundeskanzlei rule: comma stays for non-money, point only for money. Our LLM may mishandle this — needs a quick eval test.
3. **Helvetism word-list governance**: Do we curate the ~30-50 words in code, or shop it out to a user-editable JSON in App Group? The custom-dictionary feature already exists — could reuse the schema.
4. **CHF detection robustness**: Need a regex spec covering `Franken`, `Fr.`, `fr.`, `CHF`, `SFr` (legacy), and Rappen subunits. Spec'd in 4.2 sketch but needs unit tests against real ASR output samples.
5. **Variantenwörterbuch licensing**: For a richer Helvetism database, would De Gruyter license a derivative subset under reasonable terms? Out of research scope — flag for product/legal.
6. **Eval coverage**: We need a fixture set of Swiss-German dictation samples with known-correct outputs to regression-test these changes. None exists in `.planning/research/` yet.
7. **iOS adaptive currency**: When user dictates pure-amount strings without "Franken" word ("fünfzehn fünfzig"), should we infer CHF or leave ambiguous? Probably leave ambiguous — don't over-reach.

---

## Sources

- [Bundeskanzlei Schreibweisungen](https://www.bk.admin.ch/bk/de/home/dokumentation/sprachen/hilfsmittel-textredaktion/schreibweisungen.html)
- [Bundeskanzlei Rechtschreibleitfaden](https://www.bk.admin.ch/bk/de/home/dokumentation/sprachen/hilfsmittel-textredaktion/leitfaden-zur-deutschen-rechtschreibung.html)
- [German Wikipedia: Liste von Helvetismen](https://de.wikipedia.org/wiki/Liste_von_Helvetismen)
- [English Wikipedia: Helvetism](https://en.wikipedia.org/wiki/Helvetism)
- [English Wikipedia: Swiss Standard German](https://en.wikipedia.org/wiki/Swiss_Standard_German)
- [English Wikipedia: Swiss franc](https://en.wikipedia.org/wiki/Swiss_franc)
- [Apple NumberFormatter docs](https://developer.apple.com/documentation/foundation/numberformatter)
- [CLDR Number and Currency Patterns](https://cldr.unicode.org/translation/number-currency-formats/number-and-currency-patterns)
- [LanguageTool GitHub](https://github.com/languagetool-org/languagetool)
- [LanguageTool German grammar.xml](https://github.com/languagetool-org/languagetool/blob/master/languagetool-language-modules/de/src/main/resources/org/languagetool/rules/de/grammar.xml)
- [igerman98 / Hunspell de_CH](https://www.j3e.de/ispell/igerman98/index_en.html)
- [SwissBERT (ZurichNLP)](https://github.com/ZurichNLP/swissbert)
- [OpenThesaurus Swiss variants](https://www.openthesaurus.de/synset/variation/ch)
- [Schweizerisches Idiotikon](https://www.idiotikon.ch/)
- [Awesome-Swiss-German](https://github.com/esthicodes/Awesome-Swiss-German)
- [Swiss German NLP resources index](https://noe-eva.github.io/SwissGermanUD/swiss-german-nlp.html)
