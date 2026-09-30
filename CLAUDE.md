# CLAUDE.md

Guidance for Claude Code in this repository. Global preferences (writing style, long-running jobs, commit trailer) live in `~/.claude/CLAUDE.md` and apply here too.

## Project

Analysis of the 2026 measles outbreak in Bangladesh, run with WHO and the Ministry of Health: a public machine-readable record, nowcasting (`epinowcast`), CFR (`cfrnow`), and vaccination and intervention priorities. Refugee camps and malnutrition are cross-cutting priorities. Public and private (WHO line list) analyses run side by side.

Read first: `docs/first-steps.md` (priorities and conventions), then `docs/plan.md`. Open questions for WHO are in `docs/who-questions.md`.

## Hard rules

- Never commit, print in full, or copy out of `assets/local/`. It holds WHO/MoH material (data dictionary, case investigation form, later the line list). The repo is public.
- Never commit extracted DGHS figures (`data/dghs-*.csv`) until publication terms are agreed. Manifests with source URLs and hashes are fine.
- Never commit `data/covariates/dhs_division.csv` or `wuenic_national.csv` until their licences are checked.
- Commit locally with conventional commits; never push without being asked.
- No language model reads numbers from source documents. Extraction is by script from the PDF text layer. An LLM may propose, a person confirms.
- `local/` is private working notes, including `local/prompt-log.md` (prompts are appended by a hook in `.claude/settings.local.json`).

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

Things that are easy to get wrong in `02`:

- The division table has three column layouts (A: 4 April to 5 May, B: 6 to 9 May, C: 10 May on). The layout is chosen per release by `layout_ok()` against the total row, not by date. Changing that function changes every value.
- The date of record is the footer date, not the URL slug.
- Hand corrections go in `assets/dghs-corrections.csv` with reason and evidence. Do not patch values in code.
- Failed continuity checks are often real DGHS revisions (explained in footnotes, `data/dghs-notes.csv`). Record them; do not "fix" them.
- Whether suspected deaths include confirmed deaths is unresolved (`bangla-review.md` item 4). Severity outputs carry both readings.

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
