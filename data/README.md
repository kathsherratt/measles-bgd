# data/

Regenerate data with the scripts in `R/data/`.

## dghs-cases.csv

DGHS case series from the measles dashboard with the latest vintage of each value.

| column | meaning |
|---|---|
| `date` | Report date (the day the counts cover) |
| `level` | `national`, `division` or `district` |
| `division` | Division, `NA` for national. Official spelling (`Barishal`) |
| `district` | District, `NA` for national and division rows |
| `measure` | `suspected`, `confirmed`, `suspected_deaths`, `confirmed_deaths`, `admitted`, `discharged`, `serum_sent` (all 24-hour counts) |
| `value` | Count for that day |
| `report_count` | Reporting units that submitted that day: national for national rows, the division's for division rows; district rows carry their division's count (none is published per district). Outside Dhaka division a unit is a district civil surgeon office |
| `fetched_at` | Vintage: when the value was fetched |
| `flag` | `prelaunch_backfill` (7 April, holds 15 March to 7 April), `prelaunch_empty` (2 to 5 April), else `NA` |

National rows are the sum of divisions. 

## dghs-cases-checks.csv

One row per check, date, division and measure. Failures are recorded, not corrected.

| column | meaning |
|---|---|
| `check` | `districts_sum_to_division`, `no_negative_values`, `no_missing_dates` (division level, from 10 April), `division_reports_sum_to_national` |
| `date`, `division`, `measure` | Key of the check (`measure` is `NA` for missing dates) |
| `expected`, `observed` | Expected and observed value (for `no_negative_values`, observed is the minimum) |
| `pass` | Whether the check passed |

## Other files

- `dghs-dashboard.csv`: raw dashboard vintages, as fetched by `R/data/01-fetch-dashboard.R`. Read `dghs-cases.csv` instead.
- `who-monthly.csv`: WHO monthly surveillance counts (CC BY-NC-SA 3.0 IGO, not committed), from `R/data/03-fetch-who-monthly.R`.
- `covariates/`: boundaries, population, DHS, WUENIC, UNICEF wasting, camp outlines, camp population (UNHCR, `camp_population.csv`) and hospitals (Healthsites.io from OpenStreetMap, ODbL, `hospitals.csv`), from `R/data/05-fetch-covariates.R`. Medical college hospitals are checked by hand in `assets/medical-colleges.csv` (government or private; the OSM list is incomplete). Two files are not committed until licences are checked.
- `parameters/`: epireview-schema parameters extracted from the literature (see its README).
- `context-figures.csv`, `camps-measles.csv`: candidate figures (age, vaccination status; camp counts) matched by `R/data/06-extract-context-figures.R` in the text of the context documents, each with its verbatim quote. Use only rows with `confirmed_by` filled.
- `camps-proposals.csv`: camp quotes located by a language model, with the token holding each number or date. `06` keeps a proposal only if the quote is a span of its page, and writes the figures to `camps-measles.csv` (`quote_type = "proposed"`), events to `camps-events.csv`, and failures and duplicates to `camps-proposals-rejected.csv`.
- `camps-ewars-weekly.csv`: weekly suspected measles/rubella cases in the camps, W52 2024 to W36 2026, digitised from the vector bars of the EWARS bulletin chart by `R/data/07-digitise-ewars-chart.py` (needs pymupdf). Syndromic counts from the weekly reporting form, far above the Health Sector bulletins' monthly suspected counts. Use only once `confirmed_by` is filled.
- `manifest-context.csv`: source URLs and hashes of context documents from `R/data/04-fetch-context.R`.
- `manifest-covariates.csv`: source URLs and hashes of covariate downloads.
- `raw/`: raw downloads, not committed.
- Press-release extraction lives in `sitrep/data/`.

Vaccination data:

-  UNICEF MICS 2025: https://mics.unicef.org/surveys?f[0]=region:3781