#!/usr/bin/env python3
"""Phase 25 Plan 25-01 follow-up — add H8 (rules-only baseline) and
H9 (expanded-dictionary baseline) rows to the existing v16_matrix.tsv.

Both H8 and H9 SKIP the LLM entirely. They apply only dictionary substitution
(longest-match-first, case-insensitive) to the raw input. This is a minimal-
viable emulation of plain-mode: the production plain-mode pipeline also runs
filler removal + ITN + Swiss-German + Swiss-number rules, but for the brand /
acronym / number / phase-face / regress fixtures in phase25_brands.tsv,
dictionary substitution is the dominant rules-layer signal — the other rules
are noise-level on this fixture set. This caveat is documented in v16_matrix.md.

H8 = rules-only with the CURRENT-PROD DictionaryService.swift defaults (no Phase 25 expansions).
H9 = rules-only with the EXPANDED dictionary (DEFAULT_DICT in run.py, which already
     adds Chemini/Cheminai/Jemini → Gemini, MPM → NPM, engine eggs → NGINX,
     Doghand/Dog Hand → Dokku, DogChee → Dockge — Phase 25 candidate expansions).

Usage:
    python3 run_h8_h9.py                              # append to default v16_matrix.tsv
    python3 run_h8_h9.py --out other.tsv              # write to a different file
"""

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent
sys.path.insert(0, str(ROOT))
import run as base_run  # noqa: E402
import run_v16_matrix as mat  # noqa: E402


# Production-shipped dictionary as of 2026-05-16 (Shared/Services/DictionaryService.swift:85-107).
# Verbatim — NO Phase 25 expansions. This is the "H8" baseline.
PROD_DICT_AS_SHIPPED = {
    "true nest": "TrueNAS", "true Nest": "TrueNAS", "TrueNest": "TrueNAS",
    "truenest": "TrueNAS", "True Nest": "TrueNAS",
    "clods.md": "Claude.MD", "DOC-G": "Dockge", "cloth desktop": "Claude Desktop",
    "medviki": "MedWiki", "matviki": "MedWiki", "add guard": "adguard", "trueness": "TrueNAS",
    "claw desktop": "Claude Desktop", "Cloud Desktop": "Claude Desktop",
    "cloud.md": "Claude.MD", "clot.md": "Claude.MD", "clod.md": "Claude.MD",
    "Swiss \"": "Swissquote", "Swiss quote": "Swissquote", "Swiss code": "Swissquote",
    "this quote": "Swissquote", "This quote": "Swissquote", "dot cloud": ".claude",
    "Zyria": "ZüriA", "Versal": "Vercel", "Acara": "Aqara", "engine X": "NGINX",
    "docg": "Dockge", "true NAS": "TrueNAS", "tail scale": "Tailscale",
    "Telscale": "Tailscale", "light llm": "LiteLLM", "LightLLM": "LiteLLM",
    "doc G": "Dockge", "Clot": "Claude", ".clot": ".claude", "clot code": "Claude Code",
    ".cloud": ".claude", "Cloud Code": "Claude Code",
    "Selguard": "Cellguard", "selguard": "Cellguard", "Mac Vesper": "MacWhisper",
    "Kai-Agenten": "KI-Agenten", "Ki-Argenten": "KI-Agenten", "KI-Agenten": "KI-Agenten",
    "AI-Agenten": "AI-Agenten", "Dektik-Tools": "Dicticus", "Sigby": "Zigbee",
    "Sig B": "Zigbee", "sig b": "Zigbee", "Sigbee": "Zigbee", "sigbee": "Zigbee",
    "Zigbee": "Zigbee", "AI Cleanup": "AI Cleanup", "AI-Cleanup": "AI Cleanup",
    "GSD": "GSD", "gest": "GSD", "GST": "GSD", "cheers": "GSD", "G.S.D.": "GSD", "gsd": "GSD",
}


def apply_dict(text: str, dictionary: dict) -> str:
    """Case-insensitive longest-match-first whole-string substitution.

    Mirrors the spirit of DictionaryService.swift's substring substitution —
    finds and replaces every occurrence of any dictionary key (case-insensitive)
    with the canonical replacement. Longest keys first so 'cloud code' beats 'cloud'.
    """
    if not text:
        return text
    keys_by_length = sorted(dictionary.keys(), key=len, reverse=True)
    out = text
    for key in keys_by_length:
        if not key:
            continue
        pattern = re.compile(re.escape(key), re.IGNORECASE)
        out = pattern.sub(dictionary[key], out)
    return out


def run_variant(variant_id: str, dictionary: dict, fixtures: list) -> list:
    rows = []
    for fix in fixtures:
        raw = fix["input"]
        expected = fix["expected"]
        output = apply_dict(raw, dictionary)
        lev_e = mat.lev_chars(output.lower(), expected.lower())
        lev_i = mat.lev_chars(output.lower(), raw.lower())
        cat = mat.category_for(fix["id"])
        rows.append({
            "variant": variant_id,
            "fixture_id": fix["id"],
            "category": cat,
            "input": raw,
            "expected": expected,
            "output": output,
            "lev_to_expected": lev_e,
            "lev_to_input": lev_i,
            "hypothesis_id": "H8" if variant_id == "H8" else "H9",
            "elapsed_s": "0.00",
        })
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=str(mat.DEFAULT_OUT),
                    help="output TSV (APPENDED, not overwritten)")
    ap.add_argument("--fixtures", default=str(mat.DEFAULT_FIXTURES))
    args = ap.parse_args()

    fixtures_path = Path(args.fixtures)
    out_path = Path(args.out)
    fixtures = mat.load_fixtures(fixtures_path)
    if not fixtures:
        sys.exit("No fixtures loaded")

    print(f"# H8 dict (prod-as-shipped): {len(PROD_DICT_AS_SHIPPED)} entries", file=sys.stderr)
    print(f"# H9 dict (expanded):        {len(base_run.DEFAULT_DICT)} entries "
          f"(+{len(base_run.DEFAULT_DICT) - len(PROD_DICT_AS_SHIPPED)} Phase 25 candidates)", file=sys.stderr)
    print(f"# fixtures: {len(fixtures)} from {fixtures_path}", file=sys.stderr)
    print(f"# out (append): {out_path}", file=sys.stderr)

    h8_rows = run_variant("H8", PROD_DICT_AS_SHIPPED, fixtures)
    h9_rows = run_variant("H9", base_run.DEFAULT_DICT, fixtures)

    if not out_path.exists():
        sys.exit(f"Output TSV does not exist; run run_v16_matrix.py first: {out_path}")

    # APPEND, do not overwrite. Skip header (file already has one).
    with out_path.open("a") as fout:
        w = csv.writer(fout, delimiter="\t", quoting=csv.QUOTE_MINIMAL)
        for r in h8_rows + h9_rows:
            w.writerow([
                r["variant"], r["fixture_id"], r["category"], r["input"], r["expected"],
                r["output"], r["lev_to_expected"], r["lev_to_input"],
                r["hypothesis_id"], r["elapsed_s"],
            ])

    # Print a concise per-category aggregate so the .md update is straightforward.
    print("\n=== H8 vs H9 per-category aggregate (sum lev_to_expected) ===")
    cats = sorted(set(r["category"] for r in h8_rows))
    print(f'{"Category":<12} {"n":>3} {"H8":>6} {"H9":>6} {"V15(known)":>10}')
    for cat in cats:
        h8_sum = sum(r["lev_to_expected"] for r in h8_rows if r["category"] == cat)
        h9_sum = sum(r["lev_to_expected"] for r in h9_rows if r["category"] == cat)
        n = sum(1 for r in h8_rows if r["category"] == cat)
        print(f'{cat:<12} {n:>3} {h8_sum:>6} {h9_sum:>6}')

    h8_tot = sum(r["lev_to_expected"] for r in h8_rows)
    h9_tot = sum(r["lev_to_expected"] for r in h9_rows)
    print(f'{"ALL":<12} {len(h8_rows):>3} {h8_tot:>6} {h9_tot:>6}')

    # Also dump fixtures where H9 outperforms H8 (i.e. Phase 25 dict expansion paid off)
    print("\n=== Fixtures where H9 beats H8 (dictionary expansion fixed it) ===")
    h8_by_id = {r["fixture_id"]: r for r in h8_rows}
    h9_by_id = {r["fixture_id"]: r for r in h9_rows}
    for fid in sorted(h8_by_id):
        h8 = h8_by_id[fid]
        h9 = h9_by_id[fid]
        if h9["lev_to_expected"] < h8["lev_to_expected"]:
            print(f"  {fid}  H8 lev={h8['lev_to_expected']} → H9 lev={h9['lev_to_expected']}")
            print(f"    input:    {h8['input'][:120]}")
            print(f"    expected: {h8['expected'][:120]}")
            print(f"    H8 out:   {h8['output'][:120]}")
            print(f"    H9 out:   {h9['output'][:120]}")

    print("\n=== Fixtures where H9 REGRESSES vs H8 (dictionary expansion hurt) ===")
    for fid in sorted(h8_by_id):
        h8 = h8_by_id[fid]
        h9 = h9_by_id[fid]
        if h9["lev_to_expected"] > h8["lev_to_expected"]:
            print(f"  {fid}  H8 lev={h8['lev_to_expected']} → H9 lev={h9['lev_to_expected']}")
            print(f"    H8 out: {h8['output'][:120]}")
            print(f"    H9 out: {h9['output'][:120]}")

    print(f"\nDone. Appended {len(h8_rows) + len(h9_rows)} rows to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
