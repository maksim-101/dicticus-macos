# Allowlist Attribution

The files `allowlist-en.txt` and `allowlist-de.txt` are derived from the hermitdave/FrequencyWords corpus (https://github.com/hermitdave/FrequencyWords), an OpenSubtitles-derived per-language frequency list.

Source: https://github.com/hermitdave/FrequencyWords (commit `master`, files `content/2018/en/en_50k.txt` and `content/2018/de/de_50k.txt`).

License: Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA 4.0). Full license: https://creativecommons.org/licenses/by-sa/4.0/

Methodology: top 1000 lemmas per language, lowercased, filtered to entries matching `^[a-zäöüß]+$` with length ≥ 2. For English, the K1 morphological variants `remind`, `apply`, `applies`, `applied`, `applying` are appended to ensure coverage of the live-capture hallucination cases (per Phase 27 RESEARCH §6.4).
