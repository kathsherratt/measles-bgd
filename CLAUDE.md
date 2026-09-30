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
- Never commit extracted DGHS figures (`data/dghs-*.csv`) until publication terms are agreed. Manifests with source URLs and hashes are fine.
- Never commit `data/covariates/dhs_division.csv` or `wuenic_national.csv` until their licences are checked, or `data/who-monthly.csv` (CC BY-NC-SA 3.0 IGO).
- Commit locally with conventional commits; never push without being asked.
- No language model reads numbers from source documents. Extraction is by script from the PDF text layer. An LLM may propose, a person confirms.
- `local/` is private: `local/prompt-log.md` (prompts appended by a hook in `.claude/settings.local.json`), call notes (they name individuals), and exploratory scripts in `local/scratch/`.

## Bengali

The DGHS PDFs' text layer is garbled by a legacy font encoding, and Claude does not read Bengali reliably. Every reading that is inferred rather than certain (row labels, column meanings, footnotes, dates, campaign headers) goes in `docs/bangla-review.md` with what was assumed and how to check it. Bengali-speaking reviewers work from that file. Never silently resolve a Bengali ambiguity in code.

## Pipeline

```sh
Rscript R/01-fetch-dghs.R        # DGHS press releases -> data/pdf/dghs/, data/manifest-dghs.csv
Rscript R/02-extract-dghs.R      # parse, correct, check -> data/dghs-daily.csv, -checks, -notes, -campaign-raw
Rscript R/03-fetch-context.R     # WHO, UN, UNICEF, camp documents
Rscript R/04-fetch-covariates.R  # HDX boundaries, population, DHS, WUENIC, camps
Rscript R/05-fetch-dashboard.R   # DGHS platform, district daily counts from 10 April (full run 2 to 3 h, run detached)
Rscript R/06-fetch-who-monthly.R # WHO monthly surveillance counts; rerun monthly for vintages
```

Running `R/05`: the platform publishes each day at 16:41 Dhaka time (11:41 BST), all at once; before then today returns zeros. Update with `--from <last date>`. The server takes about 6 s a request, so a full run is 2 to 3 hours: run it detached. Never edit a script while a detached `Rscript` is running it: R reads the file as it goes, and the edit breaks the remaining steps.

Things that are easy to get wrong in `02`:

- The division table has three column layouts (A: 4 April to 5 May, B: 6 to 9 May, C: 10 May on). The layout is chosen per release by `layout_ok()` against the total row, not by date. Changing that function changes every value.
- The date of record is the footer date, not the URL slug.
- Hand corrections go in `assets/dghs-corrections.csv` with reason and evidence. Do not patch values in code.
- Failed continuity checks are often real DGHS revisions (explained in footnotes, `data/dghs-notes.csv`). Record them; do not "fix" them.
- Whether suspected deaths include confirmed deaths is unresolved (`bangla-review.md` item 4), though WHO's total of about 1,100 deaths points to separate counts. Severity outputs carry both readings.

## What the data are (findings to keep in mind)

- All reported cases are hospitalised cases (WHO call). DGHS counts are admissions, not infections.
- DGHS press releases and the platform dashboard are the same data. Published days are final; the platform puts corrections on the right days, so prefer it. There is no public reporting triangle.
- WHO monthly surveillance is a different stream (EPI case investigations, close to the line list). From June it stopped epi-linking and tests nearly every suspect, so its fall after May is partly a change in classification. Among tested suspects, lab positivity is 45 to 70% (1 to 7% in 2025).
- The national daily count (about 1,000) is the sum of staggered division epidemics; work by division.
- Details and numbers are in `docs/plan.md`.

## Conventions

- R, `data.table`, numbered scripts `R/NN-verb-object.R`, `here::here()` paths, same comment style as `R/01-fetch-dghs.R`. Matches `../bvd-sitreps`.
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
