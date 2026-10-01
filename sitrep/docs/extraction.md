# DGHS extraction design

The press releases are the secondary DGHS source; the platform dashboard is primary. They are still needed for the period before the platform, the footnotes, the campaign tables and the cross-check, and extracting them is the hard part.

Findings from the first look:

- Text layer present in every file checked. Numbers read cleanly with `pdftools`. Digits are sometimes ASCII, sometimes Bengali, sometimes mixed within a single number (`2৩১`).
- Bengali labels are garbled by a legacy font encoding (Unicode fonts on some pages, SutonnyMJ ASCII glyphs on others, e.g. `MZ 24 N›Uvq`). Labels cannot be matched by exact string.
- The division table has 12 columns: six measures, first for the last 24h and then cumulative since 15 March. The column order changed twice. Each period was identified by matching the total row against the next day's cumulatives.

  | Layout | Releases | 24h columns | Cumulative columns |
  |---|---|---|---|
  | 0 | 2 to 3 April | National only (SutonnyMJ glyphs on 3 April) | National only |
  | A | 4 April to 5 May | suspected, admitted, discharged, suspected deaths, confirmed, confirmed deaths | same order as 24h |
  | B | 6 to 9 May | as A | suspected, admitted, discharged, confirmed, confirmed deaths, suspected deaths |
  | C | 10 May onwards | suspected, suspected deaths, confirmed, confirmed deaths, admitted, discharged | same order as 24h |

  Page 1 national headline blocks change independently of this: suspected and confirmed deaths swap position between May and September. The campaign tables start around 1 May, with 24h doses at first and cumulative only by September.
- Cumulatives are revised. Suspected cases fell from 57,846 (release labelled 17 May) to 54,911 (labelled 18 May), then continued rising from the lower base. Revisions have to be flagged, not treated as errors. They are also the only public signal of backfill.
- Slug dates are unreliable. Five dates appear twice, and each sits next to a missing day (9 April twice, 10 April missing; 18 May twice, 19 May missing). Early September slugs drop the leading zero. The reporting window printed on page 1 is the date of record.
- Some releases contain errors. The 11 August release repeats the cumulative figures in place of the 24h columns. There are gaps with no release (e.g. 15 to 18 September), where only the sum of 24h counts can be recovered, from the cumulatives on either side.
- 6 April was downloaded empty on the first run and has been refetched. The manifest lists the remaining gaps.

Implemented in `sitrep/R/02-extract.R` (29 September):

1. Deterministic parse of the `pdftools` text layer; no LLM. Rows are matched to divisions on stable substrings of the garbled labels (37 spellings of 9 names).
2. The layout is chosen per release by testing A, B and C against the total row: 24h ≤ cumulative, suspected ≥ confirmed ≥ confirmed deaths, admitted ≥ discharged, suspected deaths under 10% of suspected. Anything other than exactly one fitting layout goes to quarantine. The result agrees with the date ranges found by hand (A 31 releases, B 4, C 132).
3. Checks: divisions sum to the total; page 1 equals the total row; cumulative(t) = cumulative(t-1) + 24h(t). Failures are recorded, not corrected.
4. Hand corrections in `sitrep/assets/corrections.csv`, each with reason and evidence (13 May truncated number; 11 August 24h columns; 1 May division cumulatives).
5. Footnotes and starred values written verbatim to `sitrep/data/dghs-notes.csv` for translation. They explain several revisions.
6. Outputs: `sitrep/data/dghs-daily.csv` (long: `report_date, date_source, geography, measure, period, value, value_raw, correction, layout, source, file`), `sitrep/data/dghs-checks.csv`, `sitrep/data/dghs-notes.csv`, `sitrep/data/dghs-campaign-raw.csv`, `sitrep/data/quarantine/dghs.csv`.

Status: 169 of 170 releases parsed (6 April needs manual transcription). The footer date resolved every duplicate slug. No release is listed for 11 days (9, 23 and 29 July; 19 August; 7, 12, 13 and 15 to 18 September); for those, only the sum of 24h counts across the gap is recoverable. 139 of 8,440 continuity checks fail, clustered in early April and at documented revisions (10, 18, 23 May; 3 to 4 August).

External validation: WHO's DON598 figures for 15 April (19,161 suspected; 2,973 confirmed; 166 suspected deaths; 12,318 admissions; 9,772 discharges) and the WHO regional bulletin's for 28 June (99,207; 11,710; 619; 93) match the extracted values exactly.

Every reading of Bengali that a person should confirm is listed in `sitrep/docs/bangla-review.md`.
