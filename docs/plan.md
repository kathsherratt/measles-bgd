# Analysis plan: measles, Bangladesh 2026

Status: draft, 29 September 2026.

## Aims

1. Build a machine-readable, public record of the outbreak from published sources.
2. Nowcast recent cases with `epinowcast`, first on public aggregate data, then on the WHO/MoH case-based data, run side by side.
3. Track severity and its drivers, particularly acute malnutrition.
4. Report Rohingya refugee camps (Cox's Bazar, Bhasan Char) separately wherever the data allow.

Tonight's priority is aim 1.

## Public sources

### Case counts

| Source | Content | Time | Space | Format | Status |
|---|---|---|---|---|---|
| DGHS daily measles press release ([listing](https://dghs.gov.bd/pages/press-releases)) | Suspected and confirmed cases, suspected and confirmed deaths, admissions, discharges; 24h and cumulative since 15 March | Daily from 2 April, 8am to 8am | National; division from mid-April; the single division and district with most deaths that day | PDF with text layer | `R/01-fetch-dghs.R` downloads all 170 |
| DGHS press release, MR campaign pages | Target, doses given, coverage | Daily from about 1 May | Division; 12 city corporations | Same PDFs | Same |
| WHO SEARO weekly epidemiological bulletin ([week 26](https://cdn.who.int/media/docs/default-source/searo/whe/wherepib/2026_13_searo_epi_bulletin.pdf)) | Weekly summary built on the DGHS releases; camp totals | Weekly | National; camps | PDF | To fetch |
| WHO Disease Outbreak News ([DON598](https://www.who.int/emergencies/disease-outbreak-news/item/2026-DON598)) | Narrative, age, vaccination status | Occasional | National | WHO API | Reuse `bvd-sitreps` `06-fetch-who.R` |
| UNICEF humanitarian sitreps ([no. 1](https://www.unicef.org/media/179846/file/Bangladesh-Humanitarian-Situation-Report-No.1(Measles-Outbreak)-8-April-2026.pdf.pdf), [no. 75](https://www.unicef.org/media/183486/file/Bangladesh-Humanitarian-Situation-Report-No.75(Mid-Year),30-June-2026.pdf.pdf)) | Age split, campaign, vitamin A, SAM treatment | About monthly | National; division | PDF | To fetch |
| UN RCO sitreps ([#3](https://bangladesh.un.org/en/315718-bangladesh-measles-outbreak-2026-situation-report-3), [#4](https://bangladesh.un.org/en/315984-bangladesh-measles-outbreak-2026-situation-report-4), [#5](https://bangladesh.un.org/en/319256-bangladesh-situation-report-5-measles-outbreak-25-june-2026)) | Consolidated national and camp picture | About monthly | National; camps | HTML/PDF | To fetch |
| ReliefWeb ([disaster page](https://reliefweb.int/disaster/ep-2026-000048-bgd)) | Index of the above | | | API | Needs an approved `appname` (403 without) |

The DGHS releases start on 2 April. Nothing daily is published for 15 March to 1 April, only the cumulative totals from 15 March onwards.

### Refugee camps

| Source | Content | Time | Space | Status |
|---|---|---|---|---|
| Rohingya Response epidemiological bulletins (EWARS; [Drive folder](https://drive.google.com/drive/folders/1TXXVczxymWd_O9vl1XL5DmfJs_znXyEg)) | Suspected measles/rubella trend, alert maps, reporting completeness by camp | Weekly | Camp (33 camps plus registered camps) | Only W36 2026 in the public folder for 2026; 4,856 suspected cases in camps this year |
| Health Sector Cox's Bazar monthly bulletin ([April](https://rohingyaresponse.org/wp-content/uploads/2026/07/Health-Sector-Coxs-Bazar-monthly-Bulletin-April-2026.pdf), [June](https://rohingyaresponse.org/wp-content/uploads/2026/08/Health-Sector-Coxs-Bazar-monthly-Bulletin-June-2026.pdf)) | Lab-confirmed and epi-linked cases, deaths, camps with active outbreaks, weekly admissions | Monthly | Camp | To fetch |
| WHO Bangladesh news ([camp campaign](https://www.who.int/bangladesh/news/detail/19-05-2026-mass-vaccination-campaign-protects-more-than-166-000-children-from-measles-in-rohingya-refugee-camps)) | Camp MR campaign from 26 April | Once | Camps | Reference |
| HDX ISCG camp outlines (`outline-of-camps-sites-of-rohingya-refugees-in-cox-s-bazar-bangladesh`) | Camp boundaries | 2024 | Camp | To fetch |
| UNHCR population by camp | Denominators | Monthly | Camp | To locate |

Open question: are camp cases included in the DGHS division totals (Chattogram division), counted separately, or both?

### Severity and malnutrition

| Source | What it gives | Space | Status |
|---|---|---|---|
| DGHS releases | Suspected and confirmed deaths and admissions by division, daily; CFR and admission ratio by division over time | Division | In the fetch |
| IPC acute malnutrition, Bangladesh ([ipcinfo](https://www.ipcinfo.org/ipc-country-analysis/details-map/en/c/1164690/?iso3=BGD)) | Acute malnutrition phase (1.6 million children 6 to 59 months, 144,000 SAM nationally); camp projection | District; camps | To fetch; not on HDX |
| BDHS 2022 ([HDX `dhs-subnational-data-for-bangladesh`](https://data.humdata.org/dataset/dhs-subnational-data-for-bangladesh)) | Wasting, stunting, underweight, MCV coverage, vitamin A | Division | To fetch |
| UNICEF child wasting indicators (HDX `unicef-nt-ant-whz-ne2`, `-ne3`) | National wasting and severe wasting series | National | To fetch |
| Nutrition Sector Cox's Bazar ([page](https://rohingyaresponse.org/sectors/coxs-bazar/nutrition/)); SMART surveys | GAM/SAM prevalence in camps; SAM admissions | Camp | To fetch |
| UNICEF sitreps | Vitamin A with MR campaign; SAM admissions | National | To fetch |
| Commentary: [Lancet](https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(26)00687-2/fulltext), [IJID](https://www.ijidonline.com/article/S1201-9712(26)00400-5/fulltext), [arXiv situational analysis](https://arxiv.org/html/2604.25951v1) | Mechanisms: missed vitamin A round in 2025, MR1/MR2 disruption 2024 to 2025, malnutrition | | Background |

What public data can support: an ecological comparison of CFR and admission rates by division, and by camp versus non-camp, against division-level wasting and vitamin A coverage. This is ecological only; individual nutritional status is needed to say anything causal.

### Denominators and covariates

HDX `cod-ab-bgd` (boundaries, adm0 to adm4, 2026), `cod-ps-bgd` (population adm1 to adm3, 2022), WorldPop age structure (under-5 share), `who-data-for-bgd` (WUENIC MCV1/MCV2 series).

## DGHS extraction design

The press releases carry most of the public signal, and extracting them is the hard part.

Findings from the first look:

- Text layer present in every file checked. Numbers read cleanly with `pdftools`. Digits are sometimes ASCII, sometimes Bengali, sometimes mixed within a single number (`2৩১`).
- Bengali labels are garbled by a legacy font encoding (Unicode fonts on some pages, SutonnyMJ ASCII glyphs on others, e.g. `MZ 24 N›Uvq`). Labels cannot be matched by exact string.
- The division table has 12 columns: six measures, first for the last 24h and then cumulative since 15 March. The column order changed twice. Each period was identified by matching the total row against the next day's cumulatives.

  | Layout | Releases | 24h columns | Cumulative columns |
  |---|---|---|---|
  | 0 | 2 to 3 April | National only (SutonnyMJ glyphs on 3 April) | National only |
  | A | 4 April to 5 May | suspected, admitted, discharged, suspected deaths, confirmed, confirmed deaths | same order as 24h |
  | B | 6 to 9 May | as A | suspected, admitted, discharged, confirmed, confirmed deaths, suspected deaths |
  | C | 10 May onwards | suspected, suspected deaths, confirmed, confirmed deaths, admitted, discharged | same order as 24h |

  Page 1 national headline blocks change independently of this: suspected and confirmed deaths swap position between May and September. The campaign tables start around 1 May, with 24h doses at first and cumulative only by September.
- Cumulatives are revised. Suspected cases fell from 57,846 (release labelled 17 May) to 54,911 (labelled 18 May), then continued rising from the lower base. Revisions have to be flagged, not treated as errors. They are also the only public signal of backfill.
- Slug dates are unreliable. Five dates appear twice, and each sits next to a missing day (9 April twice, 10 April missing; 18 May twice, 19 May missing). Early September slugs drop the leading zero. The reporting window printed on page 1 is the date of record.
- Some releases contain errors. The 11 August release repeats the cumulative figures in place of the 24h columns. There are gaps with no release (e.g. 15 to 18 September), where only the sum of 24h counts can be recovered, from the cumulatives on either side.
- 6 April was downloaded empty on the first run and has been refetched. The manifest lists the remaining gaps.

Implemented in `R/02-extract-dghs.R` (29 September):

1. Deterministic parse of the `pdftools` text layer; no LLM. Rows are matched to divisions on stable substrings of the garbled labels (37 spellings of 9 names).
2. The layout is chosen per release by testing A, B and C against the total row: 24h ≤ cumulative, suspected ≥ confirmed ≥ confirmed deaths, admitted ≥ discharged, suspected deaths under 10% of suspected. Anything other than exactly one fitting layout goes to quarantine. The result agrees with the date ranges found by hand (A 31 releases, B 4, C 132).
3. Checks: divisions sum to the total; page 1 equals the total row; cumulative(t) = cumulative(t-1) + 24h(t). Failures are recorded, not corrected.
4. Hand corrections in `assets/dghs-corrections.csv`, each with reason and evidence (13 May truncated number; 11 August 24h columns; 1 May division cumulatives).
5. Footnotes and starred values written verbatim to `data/dghs-notes.csv` for translation. They explain several revisions.
6. Outputs: `data/dghs-daily.csv` (long: `report_date, date_source, geography, measure, period, value, value_raw, correction, layout, source, file`), `data/dghs-checks.csv`, `data/dghs-notes.csv`, `data/dghs-campaign-raw.csv`, `data/quarantine/dghs.csv`.

Status: 169 of 170 releases parsed (6 April needs manual transcription). The footer date resolved every duplicate slug. No release is listed for 11 days (9, 23 and 29 July; 19 August; 7, 12, 13 and 15 to 18 September); for those, only the sum of 24h counts across the gap is recoverable. 139 of 8,440 continuity checks fail, clustered in early April and at documented revisions (10, 18, 23 May; 3 to 4 August).

External validation: WHO's DON598 figures for 15 April (19,161 suspected; 2,973 confirmed; 166 suspected deaths; 12,318 admissions; 9,772 discharges) and the WHO regional bulletin's for 28 June (99,207; 11,710; 619; 93) match the extracted values exactly.

Every reading of Bengali that a person should confirm is listed in `bangla-review.md`.

## Reporting delays in public data

### Vintages

A reporting triangle needs the same quantity reported more than once as it is revised. What exists publicly:

| Candidate | What it holds | Vintage of a dated series? | Checked |
|---|---|---|---|
| DGHS daily releases | Cumulative and 24h totals, national and division | No. Each release is a vintage of the running totals only. No series by onset date or report date is ever republished. | 170 releases, 2 April to 29 September |
| Wayback Machine, DGHS PDFs | 148 captures of 82 DGHS object-storage PDFs | No. Only 4 are measles releases, and all 4 match today's files byte for byte. No sign that files are replaced after publication, but few are covered. | CDX API, SHA-1 comparison |
| Wayback Machine, DGHS listing | 58 captures of the listing page, May to September | No. It shows only when each release first appeared. | CDX API |
| DGHS health dashboard (`dashboard.dghs.gov.bd`) | Routine EPI coverage by district and month (`dashboard_epi.php`) | No, and it returns 403 from outside Bangladesh. One Wayback capture (30 March). Useful as a coverage covariate if WHO can export it. | |
| Wikipedia article | 166 revisions, 5 April to 18 September, with a division table | No. It transcribes DGHS releases. It adds only a timestamp for when figures were public. | MediaWiki API |
| WHO regional office weekly bulletins | Daily national series plotted from the DGHS releases | Only if DGHS revised its back series, which it does not publish | Week 26 read |

There is no public vintage of a series indexed by onset or report date, so no public reporting triangle and no public reporting-delay distribution. Dated line-list extracts from WHO are the only route. Any weekly exports WHO has kept since April would be a ready-made set of vintages.

### What aggregate public data can still show

| Signal | Construction | What it identifies | Limit |
|---|---|---|---|
| Revisions | Σ24h(t) minus Δcumulative(t), by division | Size and timing of backfill and deduplication (e.g. -2,935 suspected on 18 May) | Cause unknown: deduplication, reclassification or late reports |
| Day-of-week | 24h counts by weekday | Reporting effect. Saturday releases (covering Friday, the weekend) mostly have two pages instead of three and lower counts. | Also include in the line-list nowcast as a report-day effect |
| Hospital length of stay | Discharges(t) + in-hospital deaths(t) = Σ admissions(t-d) f(d), by division | Admission-to-exit delay and bed occupancy | Deconvolution; deaths are not all in hospital |
| Delay-adjusted CFR | Deaths(t) against cases(t-d) with an onset-to-death delay from the literature; `cfr` package (Epiverse) | Aggregate CFR by division; the benchmark for `cfrnow` | Report-date to report-date, so the delay is not a biological one |
| Confirmation lag | Confirmed(t) against suspected(t-d) | Upper bound on lab turnaround at best | Not identifiable while the share tested varies |

## Line-list analysis

### Delays in the case investigation data

| Delay | Fields | Use |
|---|---|---|
| Fever to rash | `DOnsetF` to `DOnsetR` | Data quality check (expect about 2 to 4 days); picks the reference date |
| Rash onset to notification | `DOnsetR` to `DNOT` | Reporting delay: the fallback triangle if there is no database entry date |
| Notification to investigation | `DNOT` to `DOI` | Surveillance performance (target 48 hours) |
| Rash onset to specimen | `DOnsetR` to `DateSpecSero` | IgM taken within 3 days of rash can be falsely negative, which inflates discards early on |
| Specimen to lab receipt to result | `DateSpecSero`, `DateSeroSent`, `DateSeroRec`, `DateMeaIgMResult` | Confirmation delay: a second triangle, of confirmed cases by onset |
| Last MR dose to onset | `DateLastMCV` to `DOnsetF` | Vaccine rash 7 to 12 days after an MR dose can meet the suspected case definition during the campaign. Needed to separate these from measles; only 0.5% complete. |
| Onset to death | not structured (`Comment` only) | CFR (below) |

### Methods

Two existing sources of method:

- `bdbv-linelist-analysis` (Julia, Turing, CensoredDistributions.jl) fits the atomic delays jointly, with shared per-case latent event times. Chained delays then add up case by case (onset to notification to specimen to result). It uses double interval censoring, compares Gamma, lognormal and Weibull by WAIC, lets strata shift the log-mean, and reports against the Charniga et al. 2024 checklist with a limitations page.
- The epinowcast suite in R: `primarycensored` (censoring and truncation), `epidist` (delays as `brms` models, covariates by formula), `epinowcast` (nowcast plus renewal), and `cfrnow` (an `epidist` model type).

Recommendation: fit each delay with `epidist` first. It sits on the same stack as `epinowcast` and `cfrnow`, runs in R, and takes stratifiers (division, age group, month, camp) by formula. It handles right truncation from each extract's cutoff. Port the `bdbv` joint-latent model only if chained delays need to add up per case, e.g. onset to confirmed result. The cost of the port is a second language and a Julia runtime. Follow the Charniga checklist and keep a limitations file in either case.

### Nowcast with `epinowcast`

- Reference date: rash onset (`DOnsetR`). Report date: date of entry into the national database if WHO has it; otherwise `DNOT`, with the caveat that notification is not when a case became visible to analysts.
- Triangles: (1) suspected cases by onset, (2) lab-confirmed cases by onset, reported at `DateMeaIgMResult`. The share tested (about 51% have `DateSpecSero`) has to be modelled or conditioned on, not assumed constant.
- Expectation: renewal process with a measles generation interval (about 11 to 12 days), incubation as the latent reporting delay, and a random walk on growth by division, as in `bvd-analysis` `nc_fit()`. Report-day (weekday) effects on the reporting delay.
- Structure: reuse the `bvd-analysis` split. An aggregation layer publishes `triangle.csv` with a `grouping` column (national, division, camp against non-camp), and the model stream reads it through `nc_triangle()`.
- Evaluation: with several extracts, rerun nowcasts as if in real time and score them against later extracts with `scoringutils`. With a single extract, only the reporting delay's stability over onset time can be checked.
- The line list covers about 47% of DGHS suspected cases (89,253 against 190,510), probably least at the peak. A line-list nowcast estimates investigated cases, not incidence. Model the investigated fraction by division and week against the DGHS totals, and scale up with that uncertainty.
- Suspected cases are the primary series; confirmed cases reflect lab policy (once an area is confirmed, WHO guidance moves to epi-linkage). Measles among untested cases can be estimated from positivity by age, onset-to-specimen interval and week.

## CFR with `cfrnow`

`cfrnow` fits a mixture-cure survival model. Each case is fatal with probability `cfr` after an onset-to-death delay, and unresolved cases are right-censored at the cutoff.

| Input | Source | Gap |
|---|---|---|
| `onset_date` | `DOnsetR` (or `DOnsetF`) | Complete |
| `death_date` (notification date of death preferred) | Only `Comment`, e.g. "DIED ON 25.08.26", 432 non-empty comments across all topics | The main gap. Parse comments as a flagged stopgap; ask for the digitised outcome and date of death, or a death line list linkable to the case investigation records |
| Record linkage | Case ID (`MSL BAN-…`) is on the form | Not in the dictionary. Without it, hospital or EOC deaths cannot be joined to cases |
| `recovery_date` (optional) | 30-day follow-up date where alive | Leave out unless follow-up is complete: patchy recovery data biases `cfr` upwards |
| Covariates | `Ageyear`, vaccination status, division, month; camp proxy; nutritional status or complications | `formula = bf(mu ~ 1, cfr ~ age_group + vaccinated + (1 \| division) + s(time))`; malnutrition only if follow-up fields exist |
| `obs_time` | Extract date | One fit per extract, cached by cutoff |
| Delay prior | Literature onset to death for measles; weakly informative, co-estimated | Check sensitivity to Gamma against lognormal |

Things that will bias the estimate if not handled:

- Death ascertainment. The DGHS releases count 1,003 suspected deaths. Deaths outside facilities, or never linked to a case record, look like survivors and pull the CFR down. Compare the deaths found in the line list with the DGHS total as a completeness check.
- Case definition. CFR among lab-confirmed cases is biased if testing favours severe cases. Report CFR for suspected, confirmed and clinically compatible cases separately.
- Changes over time. The MR campaign, vitamin A and case management changed during the outbreak, so `cfr` gets a smooth on time.
- Benchmark. The aggregate delay-adjusted CFR and hospital outcome ratio from public data, by division, and a naive CFR among line-list cases with onset more than 30 days before the cutoff. Six months in, most cases have resolved. `cfrnow` earns its place for the recent tail and for CFR changing over time; it is weakly identified otherwise, since it rests on the delay prior.
- Death definitions. Until item 4 of `bangla-review.md` is settled, every CFR is reported for both readings (suspected deaths inclusive of confirmed, or separate).
- Line-list CFR is a lower bound where deaths are found only in free text or missing; calibrate against the DGHS death count.

## What the case investigation data add

Read from `assets/local/` (data dictionary, 33 variables, 89,253 records; case investigation form, May 2026 print). Not committed.

| Gap in public data | Case investigation data | Caveat or question |
|---|---|---|
| Onset date | `DOnsetF`, `DOnsetR` complete for all records | |
| Report date for a triangle | `DNOT` is notification to the focal person | Need date entered into the national database, or dated extracts (snapshots) |
| Age | `Ageyear` 98% complete, `DOB` 19% | |
| Vaccination | `MeaslesVaccinated`, `DosesMCV`, `DosesRCV`; `DateLastMCV` 0.5% complete | Card versus recall and SIA doses are on the form but not in the dictionary |
| Lab | IgM results and dates, about 50% sampled | Sampling policy during the outbreak (all cases, or a sample per cluster?) |
| Geography | Division to village/ward; facility | Camp number and nationality/FDMN are not captured; Ukhia, Teknaf and Bhasan Char (Hatiya) upazilas are the proxy |
| Severity | None in the dictionary except free-text `Comment` ("DIED ON 25.08.26") | The form collects admission date, 30-day follow-up, complications (malnutrition, ARI, diarrhoea, otitis, encephalitis) and outcome with date of death. Are these digitised? |
| Nutritional status at presentation | Not on the form | Is MUAC or weight-for-height recorded anywhere, e.g. in hospital death reviews? |
| Coverage | 89,253 records against 190,510 suspected cases in the press releases | Are the case investigation data and the Health Emergency Operation Centre (EOC) counts different streams? Is the difference cases not investigated, or reporting lag? |

## Questions for WHO

Consolidated, in priority order, in `who-questions.md`.

## Repository layout

```
R/01-fetch-dghs.R         DGHS press releases       -> data/pdf/dghs/, data/manifest-dghs.csv
R/02-extract-dghs.R       parse, correct, check     -> data/dghs-*.csv (gitignored)
R/03-fetch-context.R      WHO, UN, UNICEF, camps    -> data/pdf/context/, data/manifest-context.csv
R/04-fetch-covariates.R   HDX                       -> data/covariates/
assets/dghs-corrections.csv   hand corrections with evidence
assets/local/             WHO/MoH material, gitignored
data/parameters/          measles parameter register (epireview schema)
docs/plan.md              this file
docs/first-steps.md       next two weeks, step by step
docs/vaccination.md       directions for vaccination and intervention analysis
docs/who-questions.md     questions for WHO
docs/bangla-review.md     readings for Bengali speakers to confirm
```

Public and private analyses sit side by side. Private data stay under a gitignored path, and only aggregates approved for release leave it.
