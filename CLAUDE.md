# CLAUDE.md

Guidance for Claude Code in this repository. Global preferences (writing style, long-running jobs, commit trailer) live in `~/.claude/CLAUDE.md` and apply here too.

## Project

Analysis of the 2026 measles outbreak in Bangladesh, with WHO and the Ministry of Health. Three modelling aims were agreed with WHO on 30 September 2026:

1. Real-time outbreak size and risk (Rt, nowcast with `epinowcast`, size including unhospitalised infections). The current focus.
2. Impact of the vaccination campaigns (April and May rounds, September mop-up). Data gathering only for now.
3. Unusual features (cases under 6 months, infections among the vaccinated, malnutrition and co-infection; severity with `cfrnow`). Data gathering only for now.

Refugee camps and malnutrition are cross-cutting. Public and private (WHO line list) analyses run side by side. IEDCR (government) is a likely partner and works in R, so code should run on their machines.

Read first: `docs/first-steps.md` (priorities, conventions, data needed for aims 2 and 3), then `docs/plan.md`. Open questions for WHO and IEDCR are in `docs/who-questions.md`.

## Hard rules

- Never commit, print in full, or copy out of `assets/local/`. It holds WHO/MoH material (data dictionary, case investigation form, later the line list). The repo is public.
- Never commit extracted DGHS figures (`data/dghs-*.csv`, `sitrep/data/dghs-*.csv`) until publication terms are agreed. Manifests with source URLs and hashes are fine.
- Never commit `data/covariates/dhs_division.csv` or `wuenic_national.csv` until their licences are checked, or `data/who-monthly.csv` (CC BY-NC-SA 3.0 IGO).
- Commit locally with conventional commits; never push without being asked.
- No language model reads numbers from source documents. Extraction is by script from the PDF text layer. An LLM may propose, a person confirms.
- `local/` is private: `local/prompt-log.md` (prompts appended by a hook in `.claude/settings.local.json`), call notes (they name individuals), and exploratory scripts in `local/scratch/`.

## Pipeline

```sh
Rscript R/data/01-fetch-dashboard.R    # DGHS platform, district daily counts from 10 April (full run 2 to 3 h, run detached)
Rscript R/data/02-tidy-dashboard.R     # latest vintage -> data/dghs-cases.csv, data/dghs-cases-checks.csv
Rscript R/data/03-fetch-who-monthly.R  # WHO monthly surveillance counts; rerun monthly for vintages
Rscript R/data/04-fetch-context.R      # WHO, UN, UNICEF, camp documents
Rscript R/data/05-fetch-covariates.R   # HDX boundaries, population, DHS, WUENIC, camps
```

Data scripts live in `R/data/`, analysis scripts in `R/analysis/`, figures in `R/plots/`. Press-release extraction lives in `sitrep/` (see `sitrep/README.md`; its rules are in `sitrep/CLAUDE.md`). Analysis reads `data/dghs-cases.csv` only, and reads sitrep outputs only through the named exports in `sitrep/README.md`.

Daily update: `R/schedule/daily.sh` runs dashboard steps 01 to 02 (from the last date held) and `sitrep/R/01` to `03`, logging to `outputs/logs/daily_*.log`. launchd runs it at 12:30 London time (`R/schedule/uk.kathsherratt.measles-bgd.daily.plist`, installed in `~/Library/LaunchAgents/`). Stop it with `launchctl bootout gui/$(id -u)/uk.kathsherratt.measles-bgd.daily`.

Running `R/data/01-fetch-dashboard.R`: the platform publishes each day at 16:41 Dhaka time (11:41 BST), all at once; before then today returns zeros. Update with `--from <last date>`. The server takes about 6 s a request, so a full run is 2 to 3 hours: run it detached. Never edit a script while a detached `Rscript` is running it: R reads the file as it goes, and the edit breaks the remaining steps.

## What the data are (findings to keep in mind)

- All reported cases are hospitalised cases (WHO call). DGHS counts are admissions, not infections.
- The platform dashboard (`R/data/01-fetch-dashboard.R`) is the primary DGHS source: it is what DGHS publishes as data (its Excel export is built from the same JSON). The press releases are the same counts and are secondary: used for the period before the platform, footnotes, campaign tables, and cross-checks. Published days are final; the platform puts corrections on the right days. There is no public reporting triangle.
- WHO monthly surveillance is a different stream (EPI case investigations, close to the line list). From June it stopped epi-linking and tests nearly every suspect, so its fall after May is partly a change in classification. Among tested suspects, lab positivity is 45 to 70% (1 to 7% in 2025).
- The national daily count (about 1,000) is the sum of staggered division epidemics; work by division.
- Details and numbers are in `docs/plan.md`.

## Conventions

- R, `data.table`, numbered scripts `R/data/NN-verb-object.R`, `here::here()` paths, same comment style as `R/data/01-fetch-dashboard.R`. Matches `../bvd-sitreps`.
- Parameters come from `data/parameters/` (epireview schema, LLM-extracted, unreviewed until ticked), never typed into scripts.
- Model fits (`epinowcast`, `epidist`, `cfrnow`) run detached with `nohup caffeinate -is` and a log in `outputs/logs/`, and are cached as `outputs/fits/<model>_<geography>_<cutoff>.rds`.
- Reports render from saved outputs only, never refit.
- Related code: `../bvd-analysis` (`nc_fit()`, `nc_triangle()` for epinowcast), `../bdbv-linelist-analysis` (joint delay model, Charniga checklist), `../cfrnow`, `../bvd-sitreps` (corpus pipeline).

## Data access notes

- `measles.dghs.gov.bd` is the facility reporting platform. Only read the public dashboard endpoints (`/api/reports/summary`, `/api/reports/geo`, `/api/public/*`), throttled to one request a second. Never call `/api/public/submit`, sign in, or touch `/api/admin/*`.
- The platform and WHO monthly series disagree on the epidemic's trajectory after May; do not merge them.
- Platform days are final once published (no backlog, edits close 14:32 Dhaka). Prefer the platform series to the press releases: it carries corrections on the right days.
- ReliefWeb API returns 403 without an approved `appname`; its website blocks plain fetches.
- `dashboard.dghs.gov.bd` returns 403 from outside Bangladesh.
- WHO SEARO bulletins: the index lists only the latest issue; issues are probed by number.
- Public camp surveillance (EWARS) has only week 36 of 2026, with no camp-level numbers.
