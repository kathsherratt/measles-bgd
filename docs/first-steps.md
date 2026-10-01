# First steps of analysis

Detailed plan for the next two weeks, 30 September 2026. It implements `plan.md` and sets up the pipeline for when WHO data arrive. Steps are numbered in the order to do them; later steps do not wait on WHO unless stated.

## Priorities

Focus: aim 1, real-time outbreak size and risk (`plan.md`). Aims 2 and 3 are data gathering only for now; what they need is listed at the end so it can be requested alongside aim 1 data.

The national daily count has sat near 1,000 hospitalised cases since April, but it is the sum of staggered division epidemics: Rajshahi fell from 216 to 26 a day between April and September while Sylhet rose from 46 to 152 and Chattogram from 159 to 252. Aim 1 is therefore a division-level analysis from the start.

Two public sources change the picture (30 September):

- The DGHS monitoring platform's dashboard exposes daily counts by district from 10 April, with serum samples sent, with corrections placed on the right days. District-level analysis is possible from public data. Published days are not revised later, so there is no public reporting triangle (`plan.md`).
- WHO's monthly surveillance counts (EPI case investigations, about 83,000 suspected in 2026, close to the 89,253 line-list records) show a different epidemic from the hospital series: measles cases peak at about 21,000 a month in April and May and fall to 5,234 in July, while DGHS hospital admissions stay near 30,000 a month to September. Explaining that gap (lagging case investigation, reporting delay by onset month, non-measles admissions, or a change in classification: epi-linked cases fall from about 16,000 a month in May to 14 in August) comes before any estimate of outbreak size.

Order of work:

1. Public data finished and checked (steps 1 and 2), with the Bangla review of priority 1 items.
2. Descriptive picture by division (step 3), including the early period before 2 April from WHO monthly data and camp documents.
3. Growth and Rt by division from the hospitalised series (step 4).
4. Bounds on outbreak size, including unhospitalised infections (step 4b).
5. Short-term forecasts by division, evaluated against the DGHS series as it arrived (step 4c).
6. Line-list nowcast pipeline on simulated data (step 5), ready for WHO or IEDCR data.
7. A brief for the next meeting, when the IEDCR director joins (step 6).

## Workflow conventions

| Convention | Choice | Why |
|---|---|---|
| Scripts | Numbered `R/data/NN-verb-object.R` and `R/analysis/NN-verb-object.R`, data.table, one job each (fetch, extract, fit, summarise), run with `Rscript` | Matches `bvd-sitreps`; each step can be rerun alone |
| Orchestration | `R/main.R` runs the main pipeline, `R/data/01` to `R/data/05`, in order; no `targets` for now | Few steps, fast; revisit when fits multiply (`targets` is not installed) |
| Packages | `renv` lockfile, committed | Collaborators get the same `epinowcast`, `epidist` and `cfrnow` versions; all three are pre-1.0 and change often |
| Paths | `here::here()` | Runs from any working directory |
| Data layers | `data/pdf/` (raw, gitignored), `data/dghs-*.csv` (dashboard series, gitignored until terms agreed), `sitrep/` (press-release extraction, with its own gitignored data), `data/covariates/` (open, committed), `assets/` (hand-curated: corrections, templates), `assets/local/` (private, gitignored) | Raw is refetchable; private never leaves the machine |
| Long jobs | `nohup caffeinate -is Rscript ... > outputs/logs/<step>_<date>.log 2>&1 &`, then poll the log | Fits outlast the IDE host |
| Caching | Each fit saved as `outputs/fits/<model>_<geography>_<cutoff>.rds`; reused if present | A crash costs one fit, and every cutoff is kept for real-time evaluation |
| Parameters | Read from `data/parameters/`, never typed into scripts | One place to update a prior; each value has a citation |
| Reporting | Quarto, `reports/` rendering from saved outputs only, never refitting | Rendering stays fast; figures match the fits on disk |
| Review | `sitrep/docs/bangla-review.md` for Bengali; corrections in `sitrep/assets/corrections.csv` with reason and evidence | Human checks are traceable |
| Commits | Conventional commits, one step per commit, local only until you push | |

## Step 0: housekeeping (half a day)

1. `renv::init()` and commit `renv.lock`.
2. `R/main.R` running `R/data/01` to `R/data/05` in order, with `--daily` doing fetch and tidy only.
3. README: purpose, data sources with licences, how to run, where private data go, and the no-publication rule for extracted DGHS data.
4. `data/README.md`: a data dictionary for `dghs-cases.csv` and `dghs-cases-checks.csv`. Done.

## Step 1: finish the public data (1 to 2 days, partly with Bangla reviewers)

| Task | Output | Blocked by |
|---|---|---|
| Extract a camp series from the context documents | `data/camps-measles.csv`: suspected, confirmed, epi-linked, deaths and admissions as reported (Health Sector monthly bulletins April to July, WHO regional bulletins, UN RCO sitreps) | Public camp surveillance bulletins give no camp-level numbers (only W36 2026 is public, and its map is binned), so a weekly camp series needs WHO |
| Parse age, vaccination status and camp figures from the WHO, UNICEF and UN documents | `data/context-figures.csv`, each row with document, page and quote | |
| WHO provisional monthly measles data for Bangladesh, 2012 to date: done, `R/data/03-fetch-who-monthly.R` | `data/who-monthly.csv` | Rerun monthly to build vintages |
| DGHS platform daily district counts, the primary DGHS series: done, `R/data/01-fetch-dashboard.R` and `R/data/02-tidy-dashboard.R` | `data/dghs-dashboard.csv`, appended with `fetched_at` per run; `data/dghs-cases.csv`, the latest vintage, with checks | Rerun with `--from` for new days; a full rerun occasionally, to detect changes of practice |

The press-release tasks (Bangla review, 6 April transcription, footnote translation, campaign tables, revision classification) are in `sitrep/README.md`.

Acceptance test: `data/dghs-cases-checks.csv` has no failures other than documented ones, and every date from 10 April to the latest has all divisions.

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
| When | Monthly WHO surveillance counts from January (before DGHS daily reporting starts), then daily suspected cases by report date, 7-day mean, eight division panels on a shared log scale; campaign start (5 April; camps 26 April) and known revisions marked | Report date is a surrogate for onset; state it. Mark Saturday releases (Friday reporting). Bin daily, which is well under half the incubation period. |
| Where | Choropleth of cumulative suspected incidence per 100,000 by division, closed legend; campaign coverage by division and city corporation as a dot plot | Division is the smallest unit with both numerator and denominator publicly |
| Among whom | Age shares from WHO and UNICEF documents (81% under five, 34% under nine months) | Line list later |
| Severity | Admission ratio by division; hospital outcome ratio, deaths / (deaths + discharges), by division; naive and delay-adjusted CFR (`cfr` package); all under both death definitions (nested and disjoint, `sitrep/docs/bangla-review.md` item 4) | Hospital outcome ratio is well defined without follow-up, but only if deaths are hospital deaths (ask WHO). Wasting (DHS 2022) is shown alongside, descriptively, with no regression: 8 divisions and confounding by access and age mix make any fitted slope misleading. |
| Camps | Weekly camp series against Cox's Bazar district and national, per 100,000 | Denominators: UNHCR registration |

Scripts: `R/analysis/10-describe.R` writes figure data and tables to `outputs/describe/`; `reports/describe.qmd` renders them.

## Step 4: growth and transmission from public data (2 to 3 days)

1. Growth rate and Rt by division from daily suspected cases by report date, with `epinowcast`: a renewal process, with incubation plus a fixed onset-to-report delay convolved explicitly (`latent_reporting_delay`), a day-of-week effect on observations, and a random walk on growth by division. A single toolchain with the line-list model later.
2. Known breaks in how cases were found, modelled or at least marked: the change of data source in mid-April, active case finding from the campaign start in each division, and the documented revisions. Measles in Bangladesh is seasonal (late winter to spring), so a decline from May is expected even without intervention.
3. The before and after campaign comparison (`vaccination.md` direction 3) is descriptive only: susceptible depletion, seasonality and changing ascertainment all confound it. A causal estimate needs a transmission model.
4. Sensitivity: confirmed cases instead of suspected; revisions spread over the preceding weeks rather than on the day (the 18 May removal implies duplicates in earlier 24h counts); generation interval ±2 days.

Fits cached by cutoff, as above. Run detached; expect minutes per division.

## Step 4b: outbreak size (aim 1, 2 to 3 days to a first bound)

Reported cases are hospitalised cases, so the outbreak is larger than the DGHS count by an unknown factor. Three routes, to be compared rather than chosen between:

| Route | What it needs | Available now? |
|---|---|---|
| Transmission model with susceptible depletion, fitted to hospitalised cases by division, estimating the hospitalised fraction | Pre-outbreak immunity by birth cohort: routine coverage (WUENIC, DHS, MICS 2019 by district), the 2024 to 2025 disruption (0.5 million missed in 2025), births; age distribution of cases | Partly: division level, national coverage |
| Ratio methods: hospitalised cases divided by the probability of hospitalisation given infection; deaths divided by the infection fatality ratio | Literature values for hospitalisation and IFR in comparable settings (gap in the parameter register) | After a literature search |
| Serology or community survey | A serosurvey or household survey in affected areas | Ask WHO and IEDCR |

The first output is a range with its assumptions stated, not a point estimate. The same model carries the counterfactuals for aim 2.

## Step 4c: short-term risk (aim 1, 1 to 2 days)

- Forecasts of hospitalised cases by division, 1 to 4 weeks ahead, from the step 4 fits.
- Evaluated as if in real time: each DGHS release is a snapshot of what was known that day, so forecasts made at past cutoffs can be scored against later releases with `scoringutils`.
- District-level risk, and the longer-term question of when susceptibles rebuild (raised on the call in the context of the political transition, and for other vaccine-preventable diseases such as diphtheria), wait for district data and the step 4b model.

## Step 5: line-list pipeline built on simulated data (about 1 day, before WHO data arrive)

The analysis code can be written and tested now, so it runs the day the data land. Keep the simulation minimal: its job is to test code against the real schema, not to be realistic.

1. `R/analysis/20-simulate-linelist.R`: a line list with exactly the 33 columns of the WHO data dictionary, onset from the step 4 fits, and delays and CFR from step 2. It includes known quirks: about half with lab dates, age with DOB mostly missing, a death date in free text.
2. `R/analysis/21-clean-linelist.R`: dates parsed and validated (fever before rash, notification after onset, and so on); death date parsed from `Comment` and flagged; age groups; camp flag from Ukhia, Teknaf and Hatiya (Bhasan Char) upazilas. Writes a tidy line list and a data-quality table.
3. `R/analysis/22-triangle.R`: reporting triangles by onset (rash) and report date (database entry date if provided, else `DNOT`), grouped national, division, and camp against non-camp; a second triangle for lab confirmation. Same `triangle.csv` layout as `bvd-analysis`.
4. `R/analysis/23-delays.R`: `epidist` fits for each delay in `plan.md` (onset to notification, notification to investigation, onset to specimen, specimen to result), stratified by division and month, with right truncation at the extract date.
5. `R/analysis/24-nowcast.R`: `epinowcast`, reusing `bvd-analysis` `nc_fit()` structure.
6. `R/analysis/25-cfr.R`: `cfrnow` with `cfr ~ age_group + vaccinated + (1 | division) + s(time)`, death-only.
7. Tests: the delay and CFR fits recover simulated parameters within their 90% intervals. This checks the code only; it says nothing about bias in the real data.
8. When real data arrive, first: discard rate, and rubella IgM positivity, by week and division. Dengue peaks in September, so suspected cases will increasingly include non-measles fever and rash. Key analyses on suspected cases, repeated on confirmed plus epi-linked cases.

## Step 6: reporting (ongoing)

- First: a short brief for the next meeting, when the IEDCR director joins. Epicurves and Rt by division, what the plateau is made of, a first bound on outbreak size, and the data asks below. IEDCR works in R, so the scripts behind it should run on their machines.
- Then `reports/sitrep.qmd`: one page per week, national and division, built from saved outputs.
- Every figure has a CSV of the data behind it, so it can be checked and reused.
- Public and private outputs are kept apart: public report from public data only; private outputs under `outputs/private/` (gitignored) until WHO agrees what can be shared.

## Data needed for aims 2 and 3

To request now, alongside aim 1 data, so the later aims are not held up. Numbers refer to `who-questions.md`.

| Aim | Data | Why | Source to ask |
|---|---|---|---|
| 2 | Campaign dates, target ages and doses by district, for the April and May rounds and the September mop-up | Timing and reach of each round | DGHS/EPI; DGHS releases give division and city corporation only |
| 2 | Target population estimates, and how they were made | Administrative coverage is 107 to 117%, and there is no electronic registry; 2 to 3 million eligible children were missed | EPI; WorldPop and census births as an alternative |
| 2 | Post-campaign coverage survey | The only direct measure of reach | WHO, UNICEF |
| 2 | Vaccination status and dose dates of cases | Separates vaccine failure from missed children | Line list |
| 2 | Routine MR1 and MR2 by district and month, 2023 to 2026 | Pre-outbreak immunity profile | DGHS EPI dashboard (not reachable from outside Bangladesh) |
| 3 | Line list linked to outcome | Severity and risk factors | WHO, IEDCR (linkage said to be possible) |
| 3 | Age in months, especially under 6 months | Cases below the age of maternal protection | Line list |
| 3 | Nutritional status (MUAC, SAM) and adenovirus or other co-infection testing | Comorbidity burden reported on the call | Hospitals, IEDCR lab |
| 3 | PCR results and genotype; the phylogenetic analysis | Introductions and timing (a molecular clock could date the undetected period, which also informs aim 1) | IEDCR, WHO regional lab |
| 3 | MICS 2019 district indicators: breastfeeding, wasting, vaccination | District covariates finer than DHS divisions | UNICEF MICS (reports public; microdata on registration) |
| 3 | Surveillance beyond hospitals | How much of the outbreak is invisible | IEDCR |
