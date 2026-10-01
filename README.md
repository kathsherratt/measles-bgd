# 2026 Bangladesh measles outbreak

Analysis of the 2026 measles outbreak in Bangladesh.
Includes: a machine-readable record from public sources, nowcasting and case fatality estimation, and analysis to support vaccination and intervention priorities.

Work in progress.
DGHS holds all rights to its data and press releases.

## Planned work

+--------------------------------+----------------------------------------------------+
| File                           | What it is                                         |
+================================+====================================================+
| `docs/plan.md`                 | Sources, reporting delays, line-list and CFR plans |
+--------------------------------+----------------------------------------------------+
| `docs/first-steps.md`          | The next steps with workflow conventions           |
+--------------------------------+----------------------------------------------------+
| `docs/vaccination.md`          | Possible vaccination and intervention analysis     |
+--------------------------------+----------------------------------------------------+
| `docs/who-questions.md`        | Questions for WHO                                  |
+--------------------------------+----------------------------------------------------+
| `sitrep/docs/extraction.md`    | Design of the press-release extraction             |
+--------------------------------+----------------------------------------------------+
| `sitrep/docs/bangla-review.md` | Readings of Bengali text TBC                       |
+--------------------------------+----------------------------------------------------+

## Data

+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Role                  | Source                                                                               | Script                                                      | Output                                                                   | Availability/notes                                                                                             |
+=======================+======================================================================================+=============================================================+==========================================================================+================================================================================================================+
| Epidemic indicators   | DGHS daily measles press releases, 2 April 2026 onwards                              | `sitrep/R/01-fetch.R`, `sitrep/R/02-extract.R`              | `sitrep/data/manifest-dghs.csv`; `sitrep/data/dghs-daily.csv` and checks | Manifest (list of sources) only. Extracted figures are not published but can be regenerated using the scripts. |
|                       |                                                                                      |                                                             |                                                                          |                                                                                                                |
|                       |                                                                                      |                                                             |                                                                          | All transcription is by script from the PDF text layer. No language model reads the numbers.                   |
|                       |                                                                                      |                                                             |                                                                          |                                                                                                                |
|                       |                                                                                      |                                                             |                                                                          | Where the text layer is wrong or ambiguous, corrections are made by hand in `sitrep/assets/corrections.csv`.   |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Environmental context | WHO, UN RCO, UNICEF and Rohingya response documents                                  | `R/data/04-fetch-context.R`                                 | `data/manifest-context.csv`                                              | Manifest only                                                                                                  |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Epidemic indicators   | DGHS measles monitoring platform (public dashboard), daily by district from 10 April | `R/data/01-fetch-dashboard.R`, `R/data/02-tidy-dashboard.R` | `data/dghs-dashboard.csv`, `data/dghs-cases.csv`                         | No, as for the press releases                                                                                  |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Epidemic indicators   | WHO provisional monthly measles surveillance, 2012 onwards                           | `R/data/03-fetch-who-monthly.R`                             | `data/who-monthly.csv`                                                   | No (CC BY-NC-SA 3.0 IGO)                                                                                       |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Environmental context | HDX: boundaries, population, DHS, WUENIC, camp outlines, wasting                     | `R/data/05-fetch-covariates.R`                              | `data/covariates/`                                                       | Openly licensed files only; DHS and WHO extracts held back pending licence check                               |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Pathogen parameters   | Measles parameters from the literature                                               | `data/parameters/`                                          | epireview-style register                                                 | Yes. Extracted by an LLM.                                                                                      |
+-----------------------+--------------------------------------------------------------------------------------+-------------------------------------------------------------+--------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+

## Running

Requires R with `data.table`, `httr2`, `pdftools`, `here`, `sf`.

``` sh
Rscript R/data/01-fetch-dashboard.R   # DGHS dashboard (full run 2 to 3 hours; use --from for new days)
Rscript R/data/02-tidy-dashboard.R    # canonical case series (seconds)
Rscript R/data/03-fetch-who-monthly.R
Rscript R/data/04-fetch-context.R
Rscript R/data/05-fetch-covariates.R
```

Press-release extraction is separate: see `sitrep/README.md`.

## Contributing

Corrections to Bengali readings are especially welcome: see `sitrep/docs/bangla-review.md`.
Please open an issue for errors.

## Licence

Code: MIT. Source documents belong to their publishers; see each manifest for URLs.
