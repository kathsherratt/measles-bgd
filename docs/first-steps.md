# First steps of analysis

Detailed plan for the next two weeks, 30 September 2026. It implements `plan.md` and sets up the pipeline for when WHO data arrive. Steps are numbered in the order to do them; later steps do not wait on WHO unless stated.

## Priorities

Nowcasting is the first analytical question, but it needs the line list. The critical path is therefore:

1. WHO answers to questions 1 to 6 in `who-questions.md`: vintages, outcome fields, linkage, coverage of the line list, and whether suspected counts include confirmed ones.
2. Bangla review of the priority 1 items. Every severity output depends on item 4.
3. Public-data description and hospital CFR (step 3). These are useful to WHO now and need nothing new.
4. A minimal line-list pipeline on simulated data (step 5), so the nowcast runs the day data arrive.

Rt from public data (step 4) and the vaccination directions come after these.

## Workflow conventions

| Convention | Choice | Why |
|---|---|---|
| Scripts | Numbered `R/NN-verb-object.R`, data.table, one job each (fetch, extract, fit, summarise), run with `Rscript` | Matches `bvd-sitreps`; each step can be rerun alone |
| Orchestration | `R/main.R` runs steps in order; no `targets` for now | Few steps, fast; revisit when fits multiply (`targets` is not installed) |
| Packages | `renv` lockfile, committed | Collaborators get the same `epinowcast`, `epidist` and `cfrnow` versions; all three are pre-1.0 and change often |
| Paths | `here::here()` | Runs from any working directory |
| Data layers | `data/pdf/` (raw, gitignored), `data/*.csv` (extracted, gitignored until terms agreed), `data/covariates/` (open, committed), `assets/` (hand-curated: corrections, templates), `assets/local/` (private, gitignored) | Raw is refetchable; private never leaves the machine |
| Long jobs | `nohup caffeinate -is Rscript ... > outputs/logs/<step>_<date>.log 2>&1 &`, then poll the log | Fits outlast the IDE host |
| Caching | Each fit saved as `outputs/fits/<model>_<geography>_<cutoff>.rds`; reused if present | A crash costs one fit, and every cutoff is kept for real-time evaluation |
| Parameters | Read from `data/parameters/`, never typed into scripts | One place to update a prior; each value has a citation |
| Reporting | Quarto, `reports/` rendering from saved outputs only, never refitting | Rendering stays fast; figures match the fits on disk |
| Review | `docs/bangla-review.md` for Bengali; corrections in `assets/dghs-corrections.csv` with reason and evidence | Human checks are traceable |
| Commits | Conventional commits, one step per commit, local only until you push | |

## Step 0: housekeeping (half a day)

1. `renv::init()` and commit `renv.lock`.
2. `R/main.R` running 01 to 04 in order, with `--daily` doing fetch and extract only.
3. README: purpose, data sources with licences, how to run, where private data go, and the no-publication rule for extracted DGHS data.
4. `data/README.md`: a data dictionary for `dghs-daily.csv`, `dghs-checks.csv` and `dghs-notes.csv`.

## Step 1: finish the public data (1 to 2 days, partly with Bangla reviewers)

| Task | Output | Blocked by |
|---|---|---|
| Bangla review of the priority 1 items in `bangla-review.md` | Reviewer initials and outcomes | Reviewers |
| Transcribe 6 April by hand | `assets/dghs-manual.csv`, read by `02` | Reviewers |
| Translate the 22 footnotes | `translation` column in `data/dghs-notes.csv`; revisions listed in `assets/dghs-revisions.csv` with cause | Reviewers |
| Label the campaign tables | `data/dghs-campaign.csv`: division and city corporation, target, doses, coverage, by date | Item 12 in the review log |
| Classify every failed continuity check as revision, source error or parse error | `assets/dghs-revisions.csv` | Footnotes |
| Extract a camp series from the context documents | `data/camps-measles.csv`: suspected, confirmed, epi-linked, deaths and admissions as reported (Health Sector monthly bulletins April to July, WHO regional bulletins, UN RCO sitreps) | Public camp surveillance bulletins give no camp-level numbers (only W36 2026 is public, and its map is binned), so a weekly camp series needs WHO |
| Parse age, vaccination status and camp figures from the WHO, UNICEF and UN documents | `data/context-figures.csv`, each row with document, page and quote | |

Acceptance test: every release date from 2 April to 29 September is either parsed, or listed with a reason (no release, quarantined, manual).

## Step 2: parameters (1 day, then ongoing)

1. Review the LLM-extracted register (`data/parameters/measles_parameters.csv`) against sources. Anything used as a prior gets a human tick.
2. Choose priors for the first models, in `data/parameters/priors.csv`, each pointing at register rows:

| Quantity | Starting point | Use |
|---|---|---|
| Incubation period (exposure to fever) | Lessler et al. 2009 lognormal (meanlog 2.526, sdlog 0.207; median about 12.5 days), via `epiparameter` | Latent delay in `epinowcast` |
| Generation interval | Klinkenberg et al. 2011 (11 to 12 days) and Vink et al. 2014 serial interval (mean 11.7 days); both abstract-only in the register, so read the full texts first | Renewal process |
| Fever to rash; admission to death; length of stay | No source found yet; estimate from the line list and from DGHS admissions and discharges | Reference date; hospital outcome ratio |
| Onset to death | Register, weakly informative; co-estimated in `cfrnow` | CFR |
| CFR by age and nutrition | Register (e.g. Portnoy 2019; Wolfson 2009) | Prior range for `cfrnow`; direction 5 in `vaccination.md` |

3. Offer the register to the epireview team (mrc-ide) once reviewed. Its columns already follow their schema.

## Step 3: descriptive analysis of public data (2 days)

Following the five questions of descriptive epidemiology. Each display has a title (what, where, when), a source footnote and one sentence stating the pattern.

| Question | Display | Notes |
|---|---|---|
| What | Case definitions (suspected, lab-confirmed, clinically compatible); share confirmed over time | The confirmed share tracks testing, so say so |
| How much | Cumulative and 7-day incidence per 100,000 by division (2022 population); rates per under-5 population alongside all-age, since 81% of cases are under five | Rates, not counts; population by 5-year band from `cod-ps-bgd`. Under-1 denominators need WorldPop or births. Division rates shown with and without Cox's Bazar until camp counting is known. |
| When | Daily suspected cases by report date, 7-day mean, eight division panels on a shared log scale; campaign start (5 April; camps 26 April) and known revisions marked | Report date is a surrogate for onset; state it. Mark Saturday releases (Friday reporting). Bin daily, which is well under half the incubation period. |
| Where | Choropleth of cumulative suspected incidence per 100,000 by division, closed legend; campaign coverage by division and city corporation as a dot plot | Division is the smallest unit with both numerator and denominator publicly |
| Among whom | Age shares from WHO and UNICEF documents (81% under five, 34% under nine months) | Line list later |
| Severity | Admission ratio by division; hospital outcome ratio, deaths / (deaths + discharges), by division; naive and delay-adjusted CFR (`cfr` package); all under both death definitions (nested and disjoint, `bangla-review.md` item 4) | Hospital outcome ratio is well defined without follow-up, but only if deaths are hospital deaths (ask WHO). Wasting (DHS 2022) is shown alongside, descriptively, with no regression: 8 divisions and confounding by access and age mix make any fitted slope misleading. |
| Camps | Weekly camp series against Cox's Bazar district and national, per 100,000 | Denominators: UNHCR registration |

Scripts: `R/10-describe.R` writes figure data and tables to `outputs/describe/`; `reports/describe.qmd` renders them.

## Step 4: growth and transmission from public data (2 to 3 days)

1. Growth rate and Rt by division from daily suspected cases by report date, with `epinowcast`: a renewal process, with incubation plus a fixed onset-to-report delay convolved explicitly (`latent_reporting_delay`), a day-of-week effect on observations, and a random walk on growth by division. A single toolchain with the line-list model later.
2. Known breaks in how cases were found, modelled or at least marked: the change of data source in mid-April, active case finding from the campaign start in each division, and the documented revisions. Measles in Bangladesh is seasonal (late winter to spring), so a decline from May is expected even without intervention.
3. The before and after campaign comparison (`vaccination.md` direction 3) is descriptive only: susceptible depletion, seasonality and changing ascertainment all confound it. A causal estimate needs a transmission model.
4. Sensitivity: confirmed cases instead of suspected; revisions spread over the preceding weeks rather than on the day (the 18 May removal implies duplicates in earlier 24h counts); generation interval ±2 days.

Fits cached by cutoff, as above. Run detached; expect minutes per division.

## Step 5: line-list pipeline built on simulated data (about 1 day, before WHO data arrive)

The analysis code can be written and tested now, so it runs the day the data land. Keep the simulation minimal: its job is to test code against the real schema, not to be realistic.

1. `R/20-simulate-linelist.R`: a line list with exactly the 33 columns of the WHO data dictionary, onset from the step 4 fits, and delays and CFR from step 2. It includes known quirks: about half with lab dates, age with DOB mostly missing, a death date in free text.
2. `R/21-clean-linelist.R`: dates parsed and validated (fever before rash, notification after onset, and so on); death date parsed from `Comment` and flagged; age groups; camp flag from Ukhia, Teknaf and Hatiya (Bhasan Char) upazilas. Writes a tidy line list and a data-quality table.
3. `R/22-triangle.R`: reporting triangles by onset (rash) and report date (database entry date if provided, else `DNOT`), grouped national, division, and camp against non-camp; a second triangle for lab confirmation. Same `triangle.csv` layout as `bvd-analysis`.
4. `R/23-delays.R`: `epidist` fits for each delay in `plan.md` (onset to notification, notification to investigation, onset to specimen, specimen to result), stratified by division and month, with right truncation at the extract date.
5. `R/24-nowcast.R`: `epinowcast`, reusing `bvd-analysis` `nc_fit()` structure.
6. `R/25-cfr.R`: `cfrnow` with `cfr ~ age_group + vaccinated + (1 | division) + s(time)`, death-only.
7. Tests: the delay and CFR fits recover simulated parameters within their 90% intervals. This checks the code only; it says nothing about bias in the real data.
8. When real data arrive, first: discard rate, and rubella IgM positivity, by week and division. Dengue peaks in September, so suspected cases will increasingly include non-measles fever and rash. Key analyses on suspected cases, repeated on confirmed plus epi-linked cases.

## Step 6: reporting (ongoing)

- `reports/sitrep.qmd`: one page per week, national and division. Epicurve, growth, CFR, campaign coverage and data caveats. Built from saved outputs.
- Every figure has a CSV of the data behind it, so it can be checked and reused.
- Public and private outputs are kept apart: public report from public data only; private outputs under `outputs/private/` (gitignored) until WHO agrees what can be shared.

## Decisions pending from the WHO meeting

| If WHO can share... | Then |
|---|---|
| Dated line-list extracts | Real reporting triangles, real-time evaluation of the nowcast with `scoringutils` |
| A single current extract | `DNOT` as report date; delay stability checked across onset time only |
| Outcome fields or a linkable death list | `cfrnow` as planned |
| Nothing individual for now | Steps 3 and 4 carry the analysis; step 5 stays on simulated data |
