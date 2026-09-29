# measles-bgd

Analysis of the 2026 measles outbreak in Bangladesh: a machine-readable record from public sources, nowcasting and case fatality estimation, and analysis to support vaccination and intervention priorities. Refugee camps and malnutrition are treated as priorities throughout.

Work in progress. Nothing here has been reviewed by DGHS or WHO. Authors are not affiliated with DGHS, which holds all rights to its press releases.

## Where to start

| File | What it is |
|---|---|
| `docs/plan.md` | Sources, extraction design, reporting delays, line-list and CFR plans |
| `docs/first-steps.md` | The next steps, in order, with workflow conventions |
| `docs/vaccination.md` | Directions for vaccination and intervention analysis |
| `docs/who-questions.md` | Questions for WHO, in priority order |
| `docs/bangla-review.md` | Readings of Bengali text that a Bengali speaker needs to confirm |

## Data

| Source | Script | Output | Published here? |
|---|---|---|---|
| DGHS daily measles press releases, 2 April 2026 onwards | `R/01-fetch-dghs.R`, `R/02-extract-dghs.R` | `data/manifest-dghs.csv`; `data/dghs-daily.csv` and checks | Manifest only. Extracted figures are not published until terms are agreed with DGHS/WHO; run the scripts to regenerate them. |
| WHO, UN RCO, UNICEF and Rohingya response documents | `R/03-fetch-context.R` | `data/manifest-context.csv` | Manifest only |
| HDX: boundaries, population, DHS, WUENIC, camp outlines, wasting | `R/04-fetch-covariates.R` | `data/covariates/` | Openly licensed files only; DHS and WHO extracts held back pending licence check |
| Measles parameters from the literature | `data/parameters/` | epireview-style register | Yes. Extracted by an LLM, not yet checked by a person. |

All transcription is by script from the PDF text layer. No language model reads the numbers. Where the text layer is wrong or ambiguous, corrections are made by hand in `assets/dghs-corrections.csv`, with the reason and evidence for each.

Private material shared by WHO or the Ministry of Health goes in `assets/local/`, which is gitignored and must never be committed.

## Running

Requires R with `data.table`, `httr2`, `pdftools`, `here`, `sf`.

```sh
Rscript R/01-fetch-dghs.R        # download new releases (a few minutes)
Rscript R/02-extract-dghs.R      # parse, correct and check (seconds)
Rscript R/03-fetch-context.R
Rscript R/04-fetch-covariates.R
```

## Contributing

Corrections to Bengali readings are especially welcome: see `docs/bangla-review.md`. Please open an issue for errors.

## Licence

Code: MIT. Source documents belong to their publishers; see each manifest for URLs.
