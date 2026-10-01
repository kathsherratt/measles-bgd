# data/

DGHS figures are not committed (`.gitignore`) until publication terms are agreed. Regenerate them with the scripts in `R/data/`.

## dghs-cases.csv

Canonical DGHS case series, from the platform dashboard. Written by `R/data/02-tidy-dashboard.R`. Long format, latest vintage of each value.

| column | meaning |
|---|---|
| `date` | Report date (the day the counts cover) |
| `level` | `national`, `division` or `district` |
| `division` | Division, `NA` for national. Official spelling (`Barishal`) |
| `district` | District, `NA` for national and division rows |
| `measure` | `suspected`, `confirmed`, `suspected_deaths`, `confirmed_deaths`, `admitted`, `discharged`, `serum_sent` (all 24-hour counts) |
| `value` | Count for that day |
| `report_count` | Number of facility reports behind the value |
| `fetched_at` | Vintage: when the value was fetched |
| `flag` | `prelaunch_backfill` (7 April, holds 15 March to 7 April), `prelaunch_empty` (2 to 5 April), else `NA` |

National rows are the sum of divisions. `discharged` is "Recovered" in the dashboard's Excel export, which omits `serum_sent`.

## dghs-cases-checks.csv

One row per check, date, division and measure. Failures are recorded, not corrected.

| column | meaning |
|---|---|
| `check` | `districts_sum_to_division`, `no_negative_values`, `no_missing_dates` (division level, from 10 April) |
| `date`, `division`, `measure` | Key of the check (`measure` is `NA` for missing dates) |
| `expected`, `observed` | Expected and observed value (for `no_negative_values`, observed is the minimum) |
| `pass` | Whether the check passed |

## Other files

- `dghs-dashboard.csv`: raw dashboard vintages, as fetched by `R/data/01-fetch-dashboard.R`. Read `dghs-cases.csv` instead.
- `who-monthly.csv`: WHO monthly surveillance counts (CC BY-NC-SA 3.0 IGO, not committed), from `R/data/03-fetch-who-monthly.R`.
- `covariates/`: boundaries, population, DHS, WUENIC, UNICEF wasting and camps, from `R/data/05-fetch-covariates.R`. Two files are not committed until licences are checked.
- `parameters/`: epireview-schema parameters extracted from the literature (see its README).
- `manifest-context.csv`: source URLs and hashes of context documents from `R/data/04-fetch-context.R`.
- `manifest-covariates.csv`: source URLs and hashes of covariate downloads.
- `raw/`: raw downloads, not committed.
- Press-release extraction lives in `sitrep/data/`.
