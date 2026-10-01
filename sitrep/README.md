# sitrep/

Extraction of the DGHS daily measles press releases (the "sitreps"), kept apart from the main pipeline. The platform dashboard is the canonical DGHS source (`data/dghs-cases.csv`); the releases are secondary.

## Purpose

- The national series before the platform: 15 March to 9 April. The dashboard loads these onto 7 April.
- Footnotes explaining revisions to cumulative counts.
- MR campaign tables, for aim 2.
- A cross-check of the dashboard (`sitrep/R/03-compare-dashboard.R`).

## How to run

From the project root:

```sh
Rscript sitrep/R/01-fetch.R              # press releases -> sitrep/data/pdf/dghs/, sitrep/data/manifest-dghs.csv
Rscript sitrep/R/02-extract.R            # parse, correct, check -> sitrep/data/dghs-daily.csv, -checks, -notes, -campaign-raw
Rscript sitrep/R/03-compare-dashboard.R  # against data/dghs-cases.csv -> sitrep/data/dghs-source-compare.csv
```

`03` needs `data/dghs-cases.csv` from `R/data/02-tidy-dashboard.R`. Rules for editing the extraction are in `sitrep/CLAUDE.md`; its design is in `sitrep/docs/extraction.md`.

## Exports

The main pipeline may read only these:

| File | Content | Status |
|---|---|---|
| `sitrep/data/dghs-daily.csv` | Pre-platform national series (and the press-release series for cross-checks) | Built |
| `sitrep/data/dghs-campaign.csv` | MR campaign tables: division and city corporation, target, doses, coverage, by date | Not built; needs the campaign tables labelled |

Neither is committed until DGHS publication terms are agreed.

## Tasks

| Task | Output | Blocked by |
|---|---|---|
| Bangla review of the priority 1 items in `sitrep/docs/bangla-review.md` | Reviewer initials and outcomes | Reviewers |
| Transcribe 6 April by hand | `sitrep/assets/manual.csv`, read by `sitrep/R/02-extract.R` | Reviewers |
| Translate the 22 footnotes | `translation` column in `sitrep/data/dghs-notes.csv`; revisions listed in `sitrep/assets/revisions.csv` with cause | Reviewers |
| Label the campaign tables | `sitrep/data/dghs-campaign.csv` | Item 12 in the review log |
| Classify every failed continuity check as revision, source error or parse error | `sitrep/assets/revisions.csv` | Footnotes |
| Dashboard against press releases: done, `sitrep/R/03-compare-dashboard.R` | `sitrep/data/dghs-source-compare.csv` | Rerun after each update of `R/data/01-fetch-dashboard.R`, `R/data/02-tidy-dashboard.R` and `sitrep/R/02-extract.R` |

Acceptance test: every release date from 2 April to 29 September is either parsed, or listed with a reason (no release, quarantined, manual).
