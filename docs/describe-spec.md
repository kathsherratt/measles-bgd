# Descriptive analysis: specification (step 3)

Draft, 2 October 2026.
Implements step 3 of `first-steps.md` and replaces `report/description.qmd`.
Public data only.

## Layout

One file, `report/describe.qmd`: data loading, derived inputs, analysis and plots, all with code shown (`echo: true`).
No separate scripts.
Modularise later if the file becomes hard to work with.

Each figure and table has a Quarto label (`fig-<name>`, `tbl-<name>`), used below to refer to it.
Code uses dplyr and tidyr with the native pipe (`|>`), with comments throughout (global `AGENTS.md`).
New code follows this; `R/data/` keeps data.table.

Sections:

1. Setup and inputs
2. What
3. How much
4. When
5. Where
6. Among whom, including camps
7. Severity

## Conventions

| Item | Rule |
|---|---|
| Primary series | `data/dghs-cases.csv`, division and district, from 10 April. National = sum of divisions |
| 2 to 9 April | Dashboard: 2 to 5 April empty; 7 April holds the backfill for 15 March to 7 April, split by division (Dhaka 4,162, Rajshahi 1,750, Chattogram 1,415 suspected, ...). Kept as a lump in cumulative counts; excluded from daily plots and rates over time |
| Before 15 March | WHO monthly only (`data/who-monthly.csv`), national. Never merged with DGHS |
| Time | Report date, labelled as such. 7-day sums are trailing, plotted at the window's last day |
| Geography | Divisions ordered west to east by centroid longitude (Rajshahi, Rangpur, Khulna, Dhaka, Mymensingh, Barishal, Sylhet, Chattogram); districts within division the same way. Cox's Bazar district shown alongside Chattogram |
| Place | Place of the reporting facility, not residence. Districts with a medical college hospital receive referrals; marked on maps and district plots. Source: Healthsites.io (OSM, HDX `bangladesh-healthsites`, ODbL), hospitals with "medical college" in the name, government or private confirmed by Kath. Hospitals per 100,000 by district shown as context only: OSM completeness varies by district |
| Denominators | 2022 census (`data/covariates/population_adm1.csv`, `population_adm2.csv`), names matched through `admin_lookup.csv`. No growth adjustment. Whether the census counts camp residents is unknown (Q12) |
| Deaths | Every death-based quantity under both readings: A, suspected deaths include confirmed; B, disjoint, total = suspected + confirmed (`sitrep/docs/bangla-review.md` item 4; Q6) |
| Ratios | From 7-day or cumulative sums, never same-day ratios |
| Displays | Epi convention: title states what, where, when; source footnote. Plain scientific language, minimal description, no interpretation beyond what is needed to read the display. Captions and any descriptive sentence are outgoing prose: Claude leaves a comment-block scaffold with the numbers as inline R, Kath writes the text (`write-prose`). Numbers are never typed |
| Interpretation | Claude's interpretation goes only in `local/interpretation-notes.md` (private, gitignored), never in the qmd, for Kath to read after viewing the figures |
| Figures | `visualise-data`: `theme_bw()` with minimal gridlines; primary `#1a1a1a`, highlight `#c0392b`, reference `#7f7f7f`. Eight divisions exceed the 7-colour limit, so division comparisons are small multiples with shared scales, not one colour per division. Continuous fills viridis. Log axes labelled in original units. Every figure has `fig-alt` text |
| Interactivity | `ggplotly()` for time series and dot plots. Maps static unless simplified boundaries (`sf::st_simplify`) render quickly; `bgd_adm1.geojson` is 4.9 MB unsimplified |
| Checks | `stopifnot()` at the point each assumption is used |

## What

What the counts are, and how classification changed.

| Label | Display | Construction |
|---|---|---|
| `tbl-measures` | Measure dictionary | Each DGHS measure and WHO monthly field: definition, source, reporting unit, nested or disjoint, open question number. WHO surveillance case definitions (suspected, clinically compatible, epi-linked, lab-confirmed), cited |
| `fig-testing` | Testing in DGHS by division, weekly | Share sampled = Σ7 `serum_sent` / Σ7 `suspected`; confirmation yield = Σ7 `confirmed` / Σ7 `serum_sent`, lag 0 and lag 7 days. Yield is not positivity: confirmations lag samples and may not all come from serum |
| `fig-who-classification` | WHO monthly classification, January 2023 to latest | Stacked counts: lab-confirmed, epi-linked, clinical, discarded. Lines: share tested = (lab-confirmed + discarded) / suspected; lab positivity = lab-confirmed / (lab-confirmed + discarded). Reproduces the ascertainment table in `plan.md` |
| `tbl-data-quality` | Data quality | Failed checks from `dghs-cases-checks.csv` (currently Barishal confirmed deaths -2 on 18 April), flagged dates, agreement with press releases from `sitrep/data/dghs-source-compare.csv` |

Checks: cumulative `confirmed` ≤ cumulative `suspected`, and cumulative `serum_sent` ≥ cumulative `confirmed`, by division.

## How much

| Label | Display | Construction |
|---|---|---|
| `tbl-cumulative` | Cumulative counts and rates by division | Suspected, confirmed, deaths (A and B) since 15 March; per 100,000 all ages. Column: under-five share of population, banded below, near or above national (8.6%; range 7.2% Khulna to 10.8% Sylhet). Rows for Cox's Bazar and Chattogram excluding Cox's Bazar |
| `fig-incidence` | 7-day incidence per 100,000 by division | Small multiples, one panel per division, shared log scale; national in grey on each panel for reference |

No under-five rate: public data have no cases by age and division.
The population band shows where more of the population is under five, so the reader can weigh all-age rates against it.

Checks: denominators matched for all 8 divisions and 64 districts.

## When

| Label | Display | Construction |
|---|---|---|
| `fig-timeline` | National timeline, January to latest | WHO monthly measles total and suspected (bars); DGHS monthly suspected from April (points); the 15 March to 7 April DGHS lump as a bracket. The WHO classification change from June marked |
| `fig-epicurve-division` | Daily suspected cases by division | 8 panels, shared log y. Daily points (Fridays distinguished), trailing 7-day mean. Vertical marks: national campaign start (5 April), camp campaign (26 April), September mop-up, division rounds when known. Missing-report marker on division-days with fewer reports than districts (not Dhaka, whose unit count is unknown) |
| `tbl-timing` | Timing by division | Date of peak 7-day mean; current 7-day mean as % of peak; week-on-week ratio for the last 4 weeks; doubling or halving time |
| `tbl-weekday` | Day-of-week effect by division | Daily count over centred 7-day mean, by weekday: median and IQR. Input to the step 4 day-of-week term |
| `tbl-timespans` | Intervals and what can estimate them | Static table, below |

`tbl-timespans` lists the intervals in this outbreak and what can estimate each.
Content (no estimates):

| Interval | Public data | WHO line list | Other source |
|---|---|---|---|
| Exposure to onset (incubation) | No | No | Literature (register) |
| Generation or serial interval | No | No (no transmission pairs) | Literature |
| Fever to rash | No | Yes (`DOnsetF`, `DOnsetR`) | |
| Rash to notification | No | Yes (`DOnsetR`, `DNOT`) | |
| Notification to investigation | No | Yes (`DNOT`, `DOI`) | |
| Rash to specimen; specimen to result | No | Yes (lab dates, about half of records) | |
| Onset to admission | No | Only if admission date is digitised (Q2) | |
| Admission to report date (facility to civil surgeon office to platform) | No; indirect signs only (missing-report days) | No | WHO or DGHS (Q22) |
| Suspected to confirmed | No (share tested varies) | Yes | |
| Admission to exit (discharge or death) | Partly: deconvolution of discharges plus deaths against admissions, by division, if deaths are hospital deaths (Q7) | Only if outcome fields are digitised (Q2) | |
| Onset to death | No | Free-text `Comment` only | Death line list (Q2) |
| Campaign dose to rash | No | `DateLastMCV`, 0.5% complete | |
| Undetected period (first infection to detection) | No | Onset dates before April, if shared | Molecular clock on sequences (IEDCR) |

The 18 May Rajshahi duplicate removal is already spread back by the dashboard (`plan.md`); noted, not marked.

Checks: no missing division-days from 10 April; peak not on the first or last day of the window, else flagged.

Waits on: division campaign dates (Q17; `sitrep/data/dghs-campaign.csv`, after Bangla review item 12); revision markers (`sitrep/assets/revisions.csv`).
Built with national dates first.

## Where

| Label | Display | Construction |
|---|---|---|
| `fig-map-cumulative` | Cumulative incidence per 100,000 by district | One choropleth, closed binned legend, division outlines |
| `fig-district-heatmap` | Weekly incidence per 100,000 by district | Tile plot: districts as rows grouped by division (west to east), weeks as columns, binned colour. Interactive |
| `fig-map-peak` | Peak month by district | One choropleth, categorical by month |
| `fig-campaign-coverage` | Campaign coverage by division and city corporation | Dot plot of administrative coverage, 100% marked |

The heatmap replaces monthly small-multiple maps: one compact figure that shows every district's timing and is cheap to render.
The peak-month map gives the spatial pattern of that timing.

Checks: every district polygon matched to a series.

Waits on: `fig-campaign-coverage` needs `sitrep/data/dghs-campaign.csv`.

## Among whom, including camps

| Label | Display | Construction |
|---|---|---|
| `tbl-reported-figures` | Reported age, sex and vaccination figures | From `data/context-figures.csv`: document, date of data, page, quote, value, denominator, `confirmed_by` |
| `fig-age-shares` | Age shares by source and date | Dot plot with denominator per point; under-five share of population for comparison |
| `tbl-camps` | Camp figures as reported | `data/camps-measles.csv`: suspected, confirmed, epi-linked, deaths, admissions, with document, period and quote. From Health Sector monthly bulletins (April to July), SEARO bulletins, UN RCO sitreps |
| `fig-camps` | Monthly incidence per 100,000: camps, Cox's Bazar district, national | Camp denominator from UNHCR registration (to fetch); Cox's Bazar with host-only and host plus camp denominators |

Both CSVs come from a script extraction of the PDF text layer (`R/data/06-extract-context-figures.R`), which records the quote for each candidate value.
A person confirms each row; rows without `confirmed_by` are not shown.

Admissions skew young relative to infections, since young children are admitted more often.

Cox's Bazar district reports 6,977 suspected cases on the dashboard to date; camp surveillance reports 4,856 suspected this year (week 36).
Whether these overlap is Q12; the two denominators bracket it.

Waits on: row confirmation (Kath); weekly camp series (Q13); Q12.

## Severity

All cases are hospital admissions, so fatality ratios are hospital fatality ratios (HFR).

| Label | Display | Construction |
|---|---|---|
| `fig-admission-ratio` | Admission ratio by division, weekly | Σ7 `admitted` / Σ7 `suspected`. Departures from 1 show what `suspected` counts beyond admissions |
| `fig-hfr-resolved` | HFR among resolved admissions by division, weekly and cumulative | Deaths / (deaths + discharges), A and B. Valid only if deaths are hospital deaths (Q7); labelled so until answered |
| `fig-deaths` | Confirmed and suspected deaths, weekly | Shows confirmation of deaths stopping from June |
| `fig-wasting` | Wasting alongside HFR by division | Two dot columns (DHS 2022 wasting; naive HFR), no fitted line. Renders locally only (`dhs_division.csv` licence unchecked) |
| `tbl-hfr` | Naive HFR by division | Cumulative deaths / cumulative suspected, A and B |
| `tbl-hfr-delay` | Delay-adjusted HFR by division | `cfr::cfr_static` and `cfr::cfr_rolling`. Last; check in with Kath before running |

The delay for `tbl-hfr-delay` runs from report to death report, so the literature onset-to-death delay does not apply directly.
Proposal: a grid of delays (mean 5, 10, 15 days; gamma, CV 0.5) until step 2 chooses one.
`cfr` computes this in closed form, so the grid takes seconds; it is last because the delay choice needs agreeing, not because of compute.
An admission-to-exit delay estimated by deconvolving discharges plus deaths against admissions could replace the grid; decide at the check-in.

Checks: HFR between 0 and 1; cumulative deaths ≤ cumulative cases by division.

Waits on: Q6 and Q7 (both readings shown meanwhile); delay choice.

## From `report/description.qmd`

| Current section | Goes to | Change |
|---|---|---|
| Daily DGHS data | When, `fig-epicurve-division` | By division. "total = confirmed + admitted" likely double counts (confirmed cases are admissions too); dropped pending Q6 |
| Pre-dashboard cumulative | When, `fig-timeline`; How much, `tbl-cumulative` | Uses the division split of the 7 April lump |
| Cumulative per 100k | How much | |
| Hospital admissions and deaths | Severity | Ratios from 7-day sums |
| Lab testing | What, `fig-testing` | Lagged weekly ratios; the early spike is the 7 April backfill |
| Spatial spread | Where | |
| Vaccination coverage, campaign | Where, `fig-campaign-coverage`; covariates to step 4b | |
| Malnutrition map | Severity, `fig-wasting` | |
| WHO historic trends | What, `fig-who-classification`; When, `fig-timeline` | |

`description.qmd` is deleted once `describe.qmd` covers it.

## Build order

| Order | Work | Can start now? |
|---|---|---|
| 1 | Setup and inputs; How much; When | Yes, with national campaign dates |
| 2 | What | Yes |
| 3 | Where, except campaign coverage | Yes |
| 4 | Severity, except `tbl-hfr-delay` | Yes |
| 5 | `06-extract-context-figures.R`; Among whom | Script yes; displays after rows are confirmed |
| 6 | `tbl-hfr-delay` | After check-in |
| 7 | Division campaign dates, revisions, Q6 and Q7 | Waiting on Bangla review and WHO |

Acceptance: `describe.qmd` renders in under a minute; all checks pass or are listed with a reason; no number typed into the text.
