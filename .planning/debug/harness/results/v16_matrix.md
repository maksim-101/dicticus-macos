# Phase 25 Plan 25-01 — V16 Hypothesis Matrix

**Date:** 2026-05-16
**Branch:** `worktree-agent-a514dc67d23b48a21` (off `feature/debug-recording-and-cleanup`)
**Plan:** `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-01-hypothesis-matrix-PLAN.md`
**Fixtures:** `.planning/debug/harness/fixtures/phase25_brands.tsv` (37 rows, 9 categories)
**Per-row TSV:** `results/v16_matrix.tsv` (260 rows: 1 header + 7 variants × 37 fixtures)

Quantifies V16 prompt hypotheses H1–H7 against V15 baseline using lev-distance vs. ground-truth `expected`. Sampler locked (`temp=0.1, top_k=40, top_p=0.9, n_predict=512, seed=42`). Each variant is built with the explicit context-builder pairing in `run.V16_CONTEXT_FN`.

## 1. Aggregate scoreboard — total / mean character-level Levenshtein vs. `expected`

Lower is better. **Bold = best in row.** `n` = fixture count per category.

| Category      | n  | V15            | V16A (H1)      | V16B (H2)      | V16C (H3)      | V16D (H4)      | V16E (H5)      | V16F (H7 bundled) |
| ------------- | -- | -------------- | -------------- | -------------- | -------------- | -------------- | -------------- | ----------------- |
| **ALL**       | 37 | 90 / 2.43      | 56 / 1.51      | 56 / 1.51      | 85 / 2.30      | 70 / 1.89      | **50 / 1.35**  | 114 / 3.08        |
| brand         | 13 | **2 / 0.15**   | 9 / 0.69       | 9 / 0.69       | **2 / 0.15**   | 11 / 0.85      | **2 / 0.15**   | 8 / 0.62          |
| anchor        | 6  | 1 / 0.17       | 1 / 0.17       | 1 / 0.17       | 1 / 0.17       | 1 / 0.17       | **0 / 0.00**   | 1 / 0.17          |
| num           | 4  | 37 / 9.25      | 38 / 9.50      | 38 / 9.50      | 37 / 9.25      | **8 / 2.00**   | 37 / 9.25      | 15 / 3.75         |
| acro          | 3  | **1 / 0.33**   | **1 / 0.33**   | **1 / 0.33**   | 2 / 0.67       | **1 / 0.33**   | 4 / 1.33       | **1 / 0.33**      |
| acro_enum     | 2  | 42 / 21.00     | **0 / 0.00**   | **0 / 0.00**   | 42 / 21.00     | 42 / 21.00     | **0 / 0.00**   | 41 / 20.50        |
| phase_face    | 2  | 7 / 3.50       | 7 / 3.50       | 7 / 3.50       | **1 / 0.50**   | 7 / 3.50       | 7 / 3.50       | 4 / 2.00          |
| ctrl          | 1  | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**      |
| regress       | 6  | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | **0 / 0.00**   | 44 / 7.33  ⚠      |

**Headline:** V16E wins the aggregate (50). V16D wins on number-integrity (8 vs 37 V15). V16C wins on phase/face homophone (1 vs 7 V15). V16A/V16B/V16E all FIX the `acro_enum` catastrophic collapse that V15 fails on (42 → 0). V16F (bundled) regresses regress-06 → empty output (see §3).

## 2. Per-category breakdown — verdict per hypothesis

### H1 — Always-on canonical Known terms (V16A)
**Result:** Mixed. **Solved:** `acro_enum` catastrophic collapse (V15: 42 → V16A: 0 for `P25-acro-enum-02`). **Regressed:** `P25-brand-07-doghand` (V15: 0 → V16A: 5 — model substitutes "Dokku" → "Docker" because "Docker" is in the canonical list and "Dokploy" is OOV). No improvement on isolated brand mishearings the V15 dictionary already covers via targeted matching.
**Verdict:** Net-positive on enumeration safety, net-negative on brand specificity. **Keep the lever but pair with a stricter canonical list.**

### H2 — Phonetic-variant mapping (V16B)
**Result:** **Identical to V16A across all 37 fixtures** (lev-to-expected matches V16A byte-for-byte). The `Chemini -> Gemini` / `MPM -> NPM` / etc. lines were already in DEFAULT_DICT after the Task 2 extension, so the targeted-context substring match was already firing for V15/V16C/V16D/V16E too. The H2 variant adds an "if you see X -> Y, replace" rule wording but the model behavior is unchanged at seed=42.
**Verdict:** No incremental value over H1 at this sampler. **Subsume into H1.**

### H3 — Domain topic words + phase/face few-shot (V16C)
**Result:** **Cleanly solves the phase/face homophone class** (V15: 7 → V16C: 1 for the 2 phase_face fixtures). `P25-phase-face-01` lev 3 → 0; `P25-phase-face-02` lev 4 → 1. No regression on any other category (slight +1 on `P25-acro-03-sabncdui` from 1 → 2, within noise).
**Verdict:** **Ship.** Cheap one-line hint + one extra few-shot for a categorical fix.

### H4 — Number-word integrity rule + few-shots (V16D)
**Result:** **Solves "forty one → 4001" class** (`P25-num-01` lev 9 → 0; `P25-num-04` lev 11 → 0). `P25-num-02` produces empty output once at seed=42 (collapse), lev 9 → 10 — small regression. Big regression on `P25-brand-01-cheminiheadless`: V15 lev 0 → V16D lev 9 (model expanded "Gemini headless about this" into a longer rephrasing — diagnosable from `output` column in TSV). Likely caused by the additional Rule 8 weight crowding out the targeted-mishearing fix.
**Verdict:** Big win on the digit-concat class; modest brand-side noise. **Ship the rule + few-shots, but verify no brand regression at the new prompt length.**

### H5 — Acronym collapse + enumeration anti-regression (V16E)
**Result:** **Best aggregate (50). Cleanly solves the `acro_enum` catastrophic collapse** (42 → 0) — same as H1/H2 but with the additional enumeration anti-regression few-shot. Improves `P25-anchor-06-dokku-anchored` by 1 lev. Slight regression on `P25-acro-03-sabncdui` (V15: 1 → V16E: 4 — model splits at wrong boundary).
**Verdict:** **Strong ship.** Best single-lever variant by aggregate.

### H6 — Anchor vs. isolated ablation
**Result:** All 6 anchor-pair fixtures land lev 0 or 1 for V15 baseline. Anchored vs. isolated forms behave identically at this fixture set — the targeted dictionary already provides the anchor implicitly. The 3 paired fixtures (gemini, nginx, dokku) show no meaningful anchor signal at seed=42. **H6 cannot be empirically distinguished from the dictionary signal in this corpus.**
**Verdict:** Inconclusive. The dictionary feeder dominates; surface-text anchoring has no measurable additive effect.

### H7 — Bundled H1+H3+H4+H5 (V16F)
**Result:** **WORST aggregate (114). Two regressions:**
- `P25-regress-06-feeding-fitting`: empty output (lev 44). V15 lev 0 → V16F lev 44. **REGRESSION.**
- `P25-num-02-fortyone`: V15 "I'm in forty one." → V16F "41." (drops "I'm in"). lev 9 → 11.
- `P25-acro-enum-02`: improves but only partially (V15: 42 → V16F: 41 — outputs "letters A B C D as separators." dropping "Use" and "in the heading").
- Bundle preserves H4's number wins (`P25-num-01` 9 → 0) and partially preserves H3's phase/face wins (`P25-phase-face-01` 3 → 0; phase-face-02 4 → 4 unchanged).
**Verdict:** **DO NOT SHIP.** Prompt-length pressure + always-on Known terms + bundled rules causes content collapse on a previously-stable fixture. Disqualified under winner criterion 2.

## Regression check
## 3. Regression check — V15 WIN fixtures (P25-regress-*)

V15 lands lev 0 on all 6 regress fixtures. Each V16 variant must hold ≥ that bar.

| Fixture                              | V15 | V16A | V16B | V16C | V16D | V16E | V16F          |
| ------------------------------------ | --- | ---- | ---- | ---- | ---- | ---- | ------------- |
| P25-regress-01-gst-gsd               | 0   | 0    | 0    | 0    | 0    | 0    | 0             |
| P25-regress-02-cloud-claude          | 0   | 0    | 0    | 0    | 0    | 0    | 0             |
| P25-regress-03-true-nas              | 0   | 0    | 0    | 0    | 0    | 0    | 0             |
| P25-regress-04-jemini-anchored       | 0   | 0    | 0    | 0    | 0    | 0    | 0             |
| P25-regress-05-opus-fourpoint-seven  | 0   | 0    | 0    | 0    | 0    | 0    | 0             |
| P25-regress-06-feeding-fitting       | 0   | 0    | 0    | 0    | 0    | 0    | **44 ⚠ REGRESSION** |

Only **V16F** fails the regression check. V15 / V16A / V16B / V16C / V16D / V16E all PASS.

There is ALSO a non-regression-set surprise on `P25-brand-01-cheminiheadless`: V15 lev 0 → V16D lev 9 (V16D's number-integrity rule wording causes the model to rephrase rather than punctuate-only). Documented but not a V15-WIN regression because the fixture is a brand class, not a regress class. Future Plan 25-03 should re-test this under the combined-prompt construct.

## 4. Anchor ablation (H6) — paired-row comparison

| Pair                              | V15 isolated | V15 anchored | Δ      | Notes                              |
| --------------------------------- | ------------ | ------------ | ------ | ---------------------------------- |
| Gemini (anchor-01 / 02)           | 0            | 0            | 0      | Targeted dict fires for both       |
| NGINX (anchor-03 / 04)            | 0            | 0            | 0      | "engine eggs" → NGINX from dict    |
| Dokku (anchor-05 / 06)            | 0            | 1            | +1     | Anchored row gets a comma→period flip; the brand fix itself succeeds in both forms |

**Conclusion:** No measurable anchoring signal at this seed. V15's targeted dictionary already handles isolated mishearings whenever the input contains a registered key. Anchor sentences are not the lever for the failures in `25-CONTEXT.md <specifics>` — the dictionary feeder coverage is. This confirms the CONTEXT.md hypothesis that the *dictionary feeder* (199/218 records with empty `dictionary_context_keys`) is the dominant lever, not surface anchoring.

## Recommendation
## 5. Recommendation

**Single-variant winner:** **V16E** (acronym-collapse + enumeration anti-regression).

- ✅ Improves aggregate (50 vs V15: 90).
- ✅ Zero regressions on the V15-WIN regress set.
- ✅ Holds steady or improves on every category except `acro` itself (where it drops `P25-acro-03-sabncdui` from 1 → 4 — a non-canonical 6-letter run; acceptable given the H5 lever fixes the 21.00-mean catastrophic-collapse case on `acro_enum`).

**However: V16E alone does NOT solve number-integrity (H4) or phase/face (H3).** A single-lever ship would leave those two regression classes unfixed.

### Recommended composite for plan 25-03 ("V16-composite")

Roll forward the following stack into `Shared/Models/CleanupPrompt.swift`:

1. **H5 rule + few-shots** (V16E core): Rule 9 — acronym-collapse with enumeration anti-regression few-shots `H D D -> HDD`, `T V -> TV`, `options A, B, C, or D` preserved.
2. **H3 hint + few-shot** (V16C core): "Domain topic words: phase, plan, workflow, framework, dictation, cleanup, prompt." line + `discuss this face first → Discuss this phase first.` few-shot.
3. **H4 rule + few-shots** (V16D core): Rule 8 — spelled-out two-digit numbers MUST render as numerals + `meeting at forty one Penn`, `two to three minutes` examples. **BUT** before shipping, re-run `P25-brand-01-cheminiheadless` under the composite to verify the brand regression seen in pure V16D does not recur (it did NOT recur in V16F's bundle, which suggests the regression is sensitive to prompt-section ordering).
4. **DO NOT** ship H1 (always-on canonical Known terms) as the dictionary feeder change. The data shows H1 hurts brand specificity (`Dokploy → Docker`/`Dokku` substitution noise) and the only place H1 wins (`acro_enum`) is also won by H5 alone via the enumeration anti-regression few-shot — without the brand-side downside. **Instead: invest the dictionary-feeder work into expanding `TextProcessingService.swift:159-165` substring matching (e.g. case-insensitive key match) so the targeted feeder fires more often, not the always-on injection.**

### Per-hypothesis verdicts

| Hyp | Lever                                       | Ship?       | Rationale                                                  |
| --- | ------------------------------------------- | ----------- | ---------------------------------------------------------- |
| H1  | Always-on canonical Known terms             | **NO**      | Brand specificity loss; H5's few-shot already fixes the only win |
| H2  | Phonetic-variant mapping                    | **YES (as dict, not as prompt rule)** | Already in DEFAULT_DICT; ship as dictionary entries in `DictionaryService.swift` |
| H3  | Domain topic words + phase/face few-shot    | **YES**     | Cleanly solves phase/face; cheap                           |
| H4  | Number-integrity rule + few-shots           | **YES**     | Solves "forty one → 4001"; re-verify under composite       |
| H5  | Acronym collapse + enumeration few-shots    | **YES**     | Best single-lever variant; fixes `acro_enum` catastrophe   |
| H6  | Anchor vs. isolated ablation                | inconclusive | Dictionary feeder dominates this signal                    |
| H7  | Bundle H1+H3+H4+H5                          | **NO**      | One regress-set fail (lev 44) + content collapse           |

## 6. Provenance

| Field             | Value |
| ----------------- | ----- |
| Matrix run        | 2026-05-16T04:55:10Z |
| Report written    | 2026-05-16T04:56:33Z |
| llama-server      | version: 8980 (41a63be28) |
| Prod GGUF         | `~/Library/Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf` |
| GGUF SHA-256 (16) | `ac0069ebccd39925` |
| Seed              | 42 (V5 reproducibility methodology) |
| Sampler           | `temp=0.1, top_k=40, top_p=0.9, n_predict=512, cache_prompt=true` |
| Stop sequences    | `In:`, `Original:`, `ORIGINAL:`, `Please provide`, `Based on`, `Glossary:`, `Examples:` |
| Total inferences  | 259 (7 variants × 37 fixtures) |
| Wall-clock        | 53.2 s (≪ 15–40 min plan estimate; prompt-cache reuse) |
| Server warm-up    | ~5 s |
| Runner            | `.planning/debug/harness/run_v16_matrix.py` |
| TSV               | `.planning/debug/harness/results/v16_matrix.tsv` |
| Plan              | `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-01-hypothesis-matrix-PLAN.md` |
| CONTEXT           | `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md` |

## 7. Downstream actions (for plan 25-03)

1. Modify `Shared/Models/CleanupPrompt.swift:60-105` to add Rules 8 (number integrity) and 9 (acronym collapse + enumeration anti-regression), plus the "Domain topic words" hint line and the four new few-shots from H3/H4/H5 above. Bump V15 → V16.
2. **DO NOT** change `Shared/Services/TextProcessingService.swift:159-165` to use always-on canonical terms. Instead extend the targeted-substring match with case-insensitive comparison so more dictionary keys fire.
3. Add the `Chemini -> Gemini`, `Cheminai -> Gemini`, `Jemini -> Gemini`, `MPM -> NPM`, `engine eggs -> NGINX`, `Doghand -> Dokku`, `Dog Hand -> Dokku`, `DogChee -> Dockge`, `true Nas -> TrueNAS` entries to `Shared/Services/DictionaryService.swift` prepopulateWithDefaults — they already exist in the harness DEFAULT_DICT but must be promoted to production. Ship as part of plan 25-03 cross-platform parity (per `feedback_cleanup_cross_platform_parity`).
4. Re-run this matrix after Plan 25-03 lands the prompt + dict changes, with a NEW V17 variant matching the composite. Confirm `P25-brand-01-cheminiheadless` (the V16D brand regression) does NOT recur and that aggregate < 50.

---

# Addendum 2026-05-16T05:10 — H8 and H9 rules-only baselines

**Why added.** §1–§7 above tested PROMPT variants but never asked "what does the rules layer alone produce?" Plain mode (no LLM, just dictionary substitution + filler + ITN + Swiss + Swiss-num) is the true zero point. Without it, any "AI wins" might be the dictionary doing the work and the LLM merely preserving it. User-mandated rerun on 2026-05-16 after `project_dictionary_dominates_brand_fixing` memory finding revealed misattribution in the original §1 scoreboard.

**Implementation caveat.** The H8/H9 emulation is **dictionary-substitution-only**, not the full plain-mode pipeline. The full plain pipeline also runs `FillerWordRemover` + `ITN` + Swiss-German + Swiss-number rules. For the brand / anchor / num / acro / phase_face / regress fixtures in `phase25_brands.tsv`, dictionary substitution is the dominant rules-layer signal — the omitted rules are noise-level on this fixture set (they target filler/ITN cases that the brand fixtures don't exercise). The H8/H9 numbers are upper-bound estimates of plain-mode performance.

- **H8** = rules-only with the **production-as-shipped** `DictionaryService.swift:85-107` defaults (no Phase 25 expansions).
- **H9** = rules-only with the **expanded** dictionary (DEFAULT_DICT in run.py — adds `Chemini/Cheminai/Jemini → Gemini`, `MPM → NPM`, `engine eggs → NGINX`, `Doghand/Dog Hand → Dokku`, `DogChee → Dockge`, `true Nas → TrueNAS`).

Runner: `.planning/debug/harness/run_h8_h9.py`. Each H8/H9 result is deterministic and reproducible without llama-server.

## §1b. Revised aggregate scoreboard — all 9 variants

Lower is better. **Bold = best in row.**

| Category    | n  | **H8**  | **H9**  | V15  | V16A | V16B | V16C | V16D | V16E    | V16F  |
| ----------- | -- | ------- | ------- | ---- | ---- | ---- | ---- | ---- | ------- | ----- |
| **ALL**     | 37 | 134     | 72      | 90   | 56   | 56   | 85   | 70   | **50**  | 114   |
| brand       | 13 | 35      | **2**   | **2**| 9    | 9    | **2**| 11   | **2**   | 8     |
| anchor      | 6  | 28      | **0**   | 1    | 1    | 1    | 1    | 1    | **0**   | 1     |
| num         | 4  | 37      | 37      | 37   | 38   | 38   | 37   | **8**| 37      | 15    |
| acro        | 3  | 8       | 8       | **1**| **1**| **1**| 2    | **1**| 4       | **1** |
| acro_enum   | 2  | **0**   | **0**   | 42   | **0**| **0**| 42   | 42   | **0**   | 41    |
| phase_face  | 2  | 6       | 6       | 7    | 7    | 7    | **1**| 7    | 7       | 4     |
| ctrl        | 1  | **0**   | **0**   | **0**| **0**| **0**| **0**| **0**| **0**   | **0** |
| regress     | 6  | 20      | 19      | **0**| **0**| **0**| **0**| **0**| **0**   | 44 ⚠  |

**Headline:** H9 (rules-only + expanded dictionary) lands at total **72** — second-best aggregate after V16E (50). On brand class, H9 (2) **ties V15 and V16E**. On anchor class, H9 (0) **beats every LLM variant**. The LLM only earns its keep on **num, acro, phase_face** — categories where dictionary substitution structurally cannot help. The acro_enum 42→0 swing previously attributed to V16A/V16E is actually V15's self-inflicted wound (plain mode at 0 doesn't have it).

## §2.8 — H8 verdict (rules-only, prod-as-shipped dictionary)

Aggregate 134 — worst of all 9 variants on brand+anchor+regress, because the current production dictionary has gaps (no Chemini, no MPM, no engine eggs, no Doghand, no DogChee). The 35 brand-class points H8 leaves on the table is **the LLM's measurable contribution at the brand dimension today**. That contribution drops to **zero** as soon as the dictionary is expanded (see H9).

**Verdict:** H8 quantifies the dictionary gap. Don't ship — but it tells us exactly how much value the LLM currently adds on isolated-brand mishearings. Answer: ~33 lev-points across 13 fixtures (35 − 2), all closed by dictionary expansion in H9.

## §2.9 — H9 verdict (rules-only, EXPANDED dictionary)

Aggregate 72 — **second-best overall**, achieved with **zero LLM calls, zero prompt changes**. The 13 brand fixtures + 6 anchor fixtures collapse to a perfect score (2 + 0) just by adding ~10 dictionary entries. The categories H9 cannot fix (num: 37, acro: 8, phase_face: 6) are exactly the categories where the LLM has unique value.

**Per-fixture wins (H8 → H9):**

| Fixture                                        | H8 | H9 | What the dict expansion did                |
| ---------------------------------------------- | -- | -- | ------------------------------------------ |
| P25-anchor-01-gemini-isolated                  | 2  | 0  | `Chemini → Gemini`                         |
| P25-anchor-02-gemini-anchored                  | 2  | 0  | `Chemini → Gemini`                         |
| P25-anchor-03-nginx-isolated                   | 7  | 0  | `engine eggs → NGINX`                      |
| P25-anchor-04-nginx-anchored                   | 7  | 0  | `engine eggs → NGINX`                      |
| P25-anchor-05-dokku-isolated                   | 5  | 0  | `Doghand → Dokku`                          |
| P25-anchor-06-dokku-anchored                   | 5  | 0  | `Doghand → Dokku`                          |
| P25-brand-01-cheminiheadless-20260515T1502     | 2  | 0  | `Chemini → Gemini`                         |
| P25-brand-02-cheminiheadless-20260515T1506     | 2  | 0  | `Chemini → Gemini`                         |
| P25-brand-03-cheminaicoli-20260516T0417        | 5  | 2  | `Cheminai → Gemini` (residual: `C Oli`)    |
| P25-brand-04-mpmsupply-20260515T0503           | 1  | 0  | `MPM → NPM`                                |
| P25-brand-05-engineeggs-20260515T0504          | 7  | 0  | `engine eggs → NGINX`                      |
| P25-brand-06/07/08-doghand-*                   | 5  | 0  | `Doghand → Dokku` (×3)                     |
| P25-brand-09-dogchee-20260515T1659             | 3  | 0  | `DogChee → Dockge`                         |
| P25-regress-04-jemini-anchored                 | 1  | 0  | `Jemini → Gemini`                          |

**Zero regressions.** H9 never makes anything worse than H8. **One residual:** P25-brand-03 leaves `C Oli` in output — add `"C Oli": "CLI"` entry to close it (would bring H9 brand total to 0).

**Verdict:** **Ship the dictionary expansion.** Single biggest, cheapest, safest lever in Phase 25. Deterministic, regression-net friendly, zero LLM risk.

## §4 — Dictionary-attribution audit (revised)

| V16 claim                              | Original verdict     | H9 alternative                  | Revised attribution                                         |
| -------------------------------------- | -------------------- | ------------------------------- | ----------------------------------------------------------- |
| V16C fixes phase/face homophone        | SHIP (H3)            | H9 stuck at 6 (rules can't)     | **Real LLM win** — H3 prompt rule irreplaceable             |
| V16D fixes `forty one → 4001`          | SHIP w/ caveat (H4)  | H9 stuck at 37 (rules can't)    | **Real LLM win** — H4 prompt rule irreplaceable             |
| V16E best aggregate, fixes acro_enum   | SHIP (H5)            | H9 also at 0 on acro_enum       | acro_enum was **V15's self-inflicted wound** — plain mode never had this problem |
| V16A/V16E "acro_enum 42 → 0"           | implicit win         | H9 also at 0                    | The 42-pt delta is V15→V16E, not rules→V16E                 |
| V16E "matches V15 brand at lev 2"      | implicit win         | H9 also at 2                    | **Brand fixes were the DICTIONARY all along** — LLM contributes 0 to isolated-brand once dict covers the phonetic variant |

## §5 — Revised recommendation for plan 25-03

Original §7 said "V16-COMPOSITE = H3 + H4 + H5." That recommendation **partially stands** but the H8/H9 analysis adds a separate, higher-ROI lever the original missed.

### Recommended hybrid ship

**Lever 1: Dictionary expansion** (`Shared/Services/DictionaryService.swift:85-107`)

Add to the `defaults` dict:
```swift
"Chemini": "Gemini", "Cheminai": "Gemini", "chemini": "Gemini", "cheminai": "Gemini",
"MPM": "NPM",
"engine eggs": "NGINX",
"Doghand": "Dokku", "Dog Hand": "Dokku", "doghand": "Dokku", "dog hand": "Dokku",
"DogChee": "Dockge", "Dog Chee": "Dockge", "dogchee": "Dockge", "dog chee": "Dockge",
"C Oli": "CLI", "c oli": "CLI",
"true Nas": "TrueNAS",
```

**Expected impact:** brand 35 → ~0, anchor 28 → 0. Zero LLM cost. Deterministic. macOS + iOS parity in one Swift file.

**Lever 2: V16-COMPOSITE prompt** (`Shared/Models/CleanupPrompt.swift`)

Adopt V16C's domain topic hint + phase/face few-shot AND V16D's number-integrity rule + few-shot. **Skip H1 (always-on canonical)** — Lever 1 makes it redundant AND it caused the `Dokploy → Docker` brand-specificity regression. **Skip H5 (acro_enum anti-regression)** ONLY if a V17 verification confirms V15's acro_enum collapse is robust enough not to recur in the composite; if uncertain, keep H5 as belt-and-suspenders since it costs ~1 few-shot.

**Expected V17 aggregate (IF additive):** brand ~0, anchor 0, num ~8, acro ~1, acro_enum 0-or-42 (verify!), phase_face ~1, regress 0, ctrl 0 → **~10 best case / ~52 worst case**. Either way ≤ V16E's 50.

### Required verification before Wave 2 ships

A V17 variant combining the above MUST be run in this harness before plan 25-03 commits Swift code. The bundle problem (V16F at 114) is real for any prompt composite. Lever 1 mitigates it for brand/anchor, but the prompt-side combination still needs a 5-minute matrix run to confirm no `feeding → fitting` style regression.

### Re-ordered plan 25-03 task structure (recommended)

1. **Task 1 (new):** Add ~16 dictionary entries from §5 Lever 1 to `Shared/Services/DictionaryService.swift`. Cross-platform parity (single file). Unit tests in `DictionaryServiceTests.swift` (macOS + iOS) — each fixture cites the V15 capture-window timestamp it derives from. **This alone is the highest-ROI single change in Phase 25.**
2. **Task 2 (was Task 1):** Add Rule 8 (number integrity) + domain topic hint + few-shots to `CleanupPrompt.swift`. Bump V15 → V16. Skip the H1 always-on canonical injection.
3. **Task 3:** Run V17 matrix verification in the harness BEFORE building. Confirm aggregate < 50 and `P25-regress-06-feeding-fitting` stays at lev 0.
4. **Task 4 (was Task 3):** Regression-net tests in `CleanupPromptTests` and `SelfCorrectionResolverTests` (macOS + iOS).
5. **Task 5 (unchanged from original Task 4):** Human UAT checkpoint.
