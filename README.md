# 2026 Bangladesh measles outbreak

Analysis of the 2026 measles outbreak in Bangladesh.
Includes: a machine-readable record from public sources, nowcasting and case fatality estimation, and analysis to support vaccination and intervention priorities.

Work in progress.
DGHS holds all rights to its data and press releases.

## Planned work

+----------------------------------+-----------------------------------------------------------------------+
| File                             | What it is                                                            |
+==================================+=======================================================================+
| `docs/plan.md`                   | Sources, extraction design, reporting delays, line-list and CFR plans |
+----------------------------------+-----------------------------------------------------------------------+
| `docs/first-steps.md`            | The next steps with workflow conventions                              |
+----------------------------------+-----------------------------------------------------------------------+
| `docs/vaccination.md`            | Possible vaccination and intervention analysis                        |
+----------------------------------+-----------------------------------------------------------------------+
| `docs/who-questions.md`          | Questions for WHO                                                     |
+----------------------------------+-----------------------------------------------------------------------+
| `docs/bangla-review.md`          | Readings of Bengali text TBC                                          |
+----------------------------------+-----------------------------------------------------------------------+

## Data

+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Role                  | Source                                                                               | Script                                     | Output                                                     | Availability/notes                                                                                             |
+=======================+======================================================================================+============================================+============================================================+================================================================================================================+
| Epidemic indicators   | DGHS daily measles press releases, 2 April 2026 onwards                              | `R/01-fetch-dghs.R`, `R/02-extract-dghs.R` | `data/manifest-dghs.csv`; `data/dghs-daily.csv` and checks | Manifest (list of sources) only. Extracted figures are not published but can be regenerated using the scripts. |
|                       |                                                                                      |                                            |                                                            |                                                                                                                |
|                       |                                                                                      |                                            |                                                            | All transcription is by script from the PDF text layer. No language model reads the numbers.                   |
|                       |                                                                                      |                                            |                                                            |                                                                                                                |
|                       |                                                                                      |                                            |                                                            | Where the text layer is wrong or ambiguous, corrections are made by hand in `assets/dghs-corrections.csv`.     |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Environmental context | WHO, UN RCO, UNICEF and Rohingya response documents                                  | `R/03-fetch-context.R`                     | `data/manifest-context.csv`                                | Manifest only                                                                                                  |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Epidemic indicators   | DGHS measles monitoring platform (public dashboard), daily by district from 10 April | `R/05-fetch-dashboard.R`                   | `data/dghs-dashboard.csv`                                  | No, as for the press releases                                                                                  |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Epidemic indicators   | WHO provisional monthly measles surveillance, 2012 onwards                           | `R/06-fetch-who-monthly.R`                 | `data/who-monthly.csv`                                     | No (CC BY-NC-SA 3.0 IGO)                                                                                       |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Environmental context | HDX: boundaries, population, DHS, WUENIC, camp outlines, wasting                     | `R/04-fetch-covariates.R`                  | `data/covariates/`                                         | Openly licensed files only; DHS and WHO extracts held back pending licence check                               |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+
| Pathogen parameters   | Measles parameters from the literature                                               | `data/parameters/`                         | epireview-style register                                   | Yes. Extracted by an LLM.                                                                                      |
+-----------------------+--------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------+

## Running

Requires R with `data.table`, `httr2`, `pdftools`, `here`, `sf`.

``` sh
Rscript R/01-fetch-dghs.R        # download new releases (a few minutes)
Rscript R/02-extract-dghs.R      # parse, correct and check (seconds)
Rscript R/03-fetch-context.R
Rscript R/04-fetch-covariates.R
```

## Contributing

Corrections to Bengali readings are especially welcome: see `docs/bangla-review.md`.
Please open an issue for errors.

## Licence

Code: MIT. Source documents belong to their publishers; see each manifest for URLs.