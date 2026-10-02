# 2026 Bangladesh measles outbreak

Analysis of the 2026 measles outbreak in Bangladesh.
Includes: a machine-readable record from public sources, nowcasting and case fatality estimation, and analysis to support vaccination and intervention priorities.

Work in progress.
DGHS holds all rights to its data and press releases.

## Planned work

| File | What it is |
|----------------------------|--------------------------------------------|
| `docs/plan.md` | Sources, reporting delays, line-list and CFR plans |
| `docs/first-steps.md` | The next steps with workflow conventions |
| `docs/vaccination.md` | Possible vaccination and intervention analysis |
| `docs/who-questions.md` | Questions for WHO |
| `sitrep/docs/extraction.md` | Design of the press-release extraction |
| `sitrep/docs/bangla-review.md` | Readings of Bengali text TBC |

## Data

### Transmission indicators

| Provider | Dataset | Contents | Scripts | Output | Availability | Notes |
|---|---|---|---|---|---|---|
| DGHS | [Measles monitoring platform dashboard](https://measles.dghs.gov.bd) | Daily suspected, confirmed, deaths, admitted, discharged and serum samples sent, by division and district (district from 10 April) | `R/data/01-fetch-dashboard.R`, `R/data/02-tidy-dashboard.R` | `data/dghs-dashboard.csv` (raw vintages), `data/dghs-cases.csv`, `data/dghs-cases-checks.csv` | [1] | Primary DGHS series. Hospitalised cases, not infections. Public dashboard endpoints only. 15 March to 7 April loaded onto 7 April. |
| DGHS | [Daily measles press releases](https://dghs.gov.bd/pages/press-releases) | Daily national and division counts from 2 April, cumulative from 15 March, footnotes on revisions | `sitrep/R/01-fetch.R`, `sitrep/R/02-extract.R`, `sitrep/R/03-compare-dashboard.R` | `sitrep/data/manifest-dghs.csv`, `sitrep/data/dghs-daily.csv`, `sitrep/data/dghs-checks.csv`, `sitrep/data/dghs-notes.csv`, `sitrep/data/dghs-source-compare.csv` | [1] | Secondary to the dashboard: pre-platform national series, footnotes, cross-check. Numbers read from the PDF text layer by script. Corrections in `sitrep/assets/corrections.csv`. |
| WHO | [Provisional monthly measles and rubella data (table 404)](https://immunizationdata.who.int/global?topic=Provisional-measles-and-rubella-data&location=) | Monthly case counts by final classification, Bangladesh, 2012 onwards | `R/data/03-fetch-who-monthly.R` | `data/who-monthly.csv` | [3] | EPI case-based surveillance, not hospital reporting. Provisional, revised monthly. Do not merge with the DGHS series. |
| Cox's Bazar Health Sector | [Rohingya response EWARS weekly bulletins](https://rohingyaresponse.org/sectors/coxs-bazar/health/) | Weekly epidemiological highlights and annex, Rohingya camps, 2025 to 2026 | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Public Google Drive folder holds week 36 of 2026 only, with no camp-level numbers. |
| Published literature (Europe PMC) | [Measles parameter register](https://europepmc.org) | Delays, CFR, R0, vaccine effectiveness, maternal antibody, risk factors | None (see `data/parameters/README.md`) | `data/parameters/measles_parameters.csv`, `data/parameters/measles_articles.csv` | [8] | epireview schema. DOI of each article in `measles_articles.csv`. No person has reviewed the rows yet. |

### Public health response

| Provider | Dataset | Contents | Scripts | Output | Availability | Notes |
|---|---|---|---|---|---|---|
| DGHS | [Daily measles press releases](https://dghs.gov.bd/pages/press-releases) | MR campaign tables: division and city corporation, target, doses, coverage by date | `sitrep/R/01-fetch.R`, `sitrep/R/02-extract.R` | `sitrep/data/dghs-campaign-raw.csv` (numbers unlabelled); `sitrep/data/dghs-campaign.csv` planned | [1] | Same source as the press-release row above. Tables unlabelled until reviewed. Administrative coverage above 100% is not the share protected. |
| WHO | [Disease Outbreak News: Measles - Bangladesh](https://www.who.int/emergencies/disease-outbreak-news/item/2026-DON598) | Outbreak situation and response narrative (2026-DON598, 23 April) | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Saved as JSON and markdown from the who.int API. |
| WHO SEARO | [SEARO epidemiological bulletins](https://www.who.int/southeastasia/outbreaks-and-emergencies/health-emergency-information-risk-assessment/sear-epi-bulletins) | Fortnightly regional bulletins, 2026 editions 1 to 19 | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Index lists only the latest issue, so the script probes PDF numbers. Early editions do not mention measles in Bangladesh. |
| UN Resident Coordinator's Office | [Bangladesh measles outbreak situation reports](https://bangladesh.un.org/en/resources/publications?search_api_fulltext=measles) | Situation reports 1 to 5, 16 April to 25 June 2026 | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Found by the site's publication search. |
| UNICEF | [Bangladesh humanitarian situation reports](https://www.unicef.org/appeals/bangladesh/situation-reports) | Situation reports No. 1 (measles outbreak, 8 April) and No. 75 (mid-year, 30 June) | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | 2026 items and any measles item. |
| Cox's Bazar Health Sector | [Health Sector Cox's Bazar](https://rohingyaresponse.org/sectors/coxs-bazar/health/) | Monthly bulletins (April to July 2026), measles clinical SOP v2.0 (29 April) | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Camp response and clinical management. |
| The DHS Program | [Bangladesh - Subnational Demographic and Health Data](https://data.humdata.org/dataset/dhs-subnational-data-for-bangladesh) | Division-level measles vaccination (children 12 to 23 months), fully vaccinated, vitamin A supplementation | `R/data/05-fetch-covariates.R` | `data/covariates/dhs_division.csv`, `data/manifest-covariates.csv` | [4] | Latest survey per indicator. Immunisation file stops at BDHS 2017-18, with no MCV1/MCV2 split. Same file as the wasting row in situational context. |
| WHO | [Bangladesh - Health Indicators](https://data.humdata.org/dataset/who-data-for-bgd) | National MCV1 and MCV2 coverage by year (WHO/UNICEF WUENIC) | `R/data/05-fetch-covariates.R` | `data/covariates/wuenic_national.csv`, `data/manifest-covariates.csv` | [4] | From the GHO immunisation indicators (`WHS8_110`, `MCV2`). |

### Situational context

| Provider | Dataset | Contents | Scripts | Output | Availability | Notes |
|---|---|---|---|---|---|---|
| OCHA FISS (source: BBS) | [Bangladesh - Subnational Administrative Boundaries](https://data.humdata.org/dataset/cod-ab-bgd) | Division (adm1) and district (adm2) boundaries, division-district lookup | `R/data/05-fetch-covariates.R` | `data/covariates/bgd_adm1.geojson`, `data/covariates/bgd_adm2.geojson`, `data/covariates/admin_lookup.csv` | [5] | Simplified to under 5 MB for mapping; do not use for areas. Spelling differs from DGHS (Barishal). |
| UNFPA (with US Census Bureau) | [Bangladesh - Subnational Population Statistics](https://data.humdata.org/dataset/cod-ps-bgd) | 2022 census-based projections, division and district: total and sex by 5-year age band | `R/data/05-fetch-covariates.R` | `data/covariates/population_adm1.csv`, `data/covariates/population_adm2.csv` | [5] | Names differ from the boundaries (Barisal, Chittagong); join on pcode. |
| Inter Sector Coordination Group | [Bangladesh - Outline of camps of Rohingya refugees in Cox's Bazar](https://data.humdata.org/dataset/outline-of-camps-sites-of-rohingya-refugees-in-cox-s-bazar-bangladesh) | Outlines of 33 camps (level A1), April 2023 | `R/data/05-fetch-covariates.R` | `data/covariates/camps.geojson` | [6] | No 2025 or 2026 population by camp on HDX; the UNHCR/RRRC series stops in 2021. |
| UNICEF Data and Analytics | [Weight-for-height <-2 SD (wasting)](https://data.humdata.org/dataset/unicef-nt-ant-whz-ne2); [Weight-for-height <-3 SD (severe wasting)](https://data.humdata.org/dataset/unicef-nt-ant-whz-ne3) | Wasting and severe wasting prevalence, Bangladesh, by survey year, sex, age, wealth quintile, residence and maternal education | `R/data/05-fetch-covariates.R` | `data/covariates/unicef_wasting.csv` | [5] | UNICEF/WHO/World Bank Joint Malnutrition Estimates, from the UNICEF SDMX API. |
| The DHS Program | [Bangladesh - Subnational Demographic and Health Data](https://data.humdata.org/dataset/dhs-subnational-data-for-bangladesh) | Division-level wasting, stunting and underweight, with severe forms | `R/data/05-fetch-covariates.R` | `data/covariates/dhs_division.csv`, `data/manifest-covariates.csv` | [4] | Same file as the vaccination row in public health response. |
| UNICEF, BBS | [Bangladesh MICS 2025 (MICS7) datasets](https://mics.unicef.org/surveys) | Household survey microdata (`hh`, `hl`, `wm`, `bh`, `ch`, `fs`): district nutrition, care-seeking, under-5 age structure | None (manual download) | `data/microdata/` | [7] | No immunisation module. MICS6 (2019) has card dates by district and is not downloaded. |
| Cox's Bazar Nutrition Sector | [Nutrition Sector Cox's Bazar](https://rohingyaresponse.org/sectors/coxs-bazar/nutrition/) | SMART surveys, quarterly bulletins, CMAM guideline, information management updates (acute malnutrition) | `R/data/04-fetch-context.R` | `data/manifest-context.csv` | [2] | Files uploaded in 2025 or 2026; meeting minutes excluded. |

### Availability key

- [1] Manifest only; scripts regenerate the data. DGHS holds all rights, and extracted data is not committed until publication terms are agreed.
- [2] Manifest only; scripts regenerate the data. Publisher documents; PDFs are not committed (`data/pdf/` is gitignored) and rights stay with each publisher.
- [3] Not committed; script regenerates the data. CC BY-NC-SA 3.0 IGO.
- [4] Not committed; script regenerates the data. HDX licence "Other", to be checked before publishing.
- [5] Committed. CC BY-IGO (HDX lists the severe wasting layer as CC BY 3.0 IGO).
- [6] Committed. CC0.
- [7] Local only, no script. Download needs registration, and the terms bar redistribution and sharing.
- [8] Committed, no script. Extracted by an LLM from the literature and not yet reviewed.

## Running

Requires R with `data.table`, `httr2`, `pdftools`, `here`, `sf`.

``` sh
Rscript R/data/01-fetch-dashboard.R   # DGHS dashboard (full run 2 to 3 hours; use --from for new days)
Rscript R/data/02-tidy-dashboard.R    # canonical case series (seconds)
Rscript R/data/03-fetch-who-monthly.R
Rscript R/data/04-fetch-context.R
Rscript R/data/05-fetch-covariates.R
```

Press-release extraction is separate: see `sitrep/README.md`.

## Contributing

Corrections to Bengali readings are especially welcome: see `sitrep/docs/bangla-review.md`.
Please open an issue for errors.

## Licence

Code: MIT. Source documents belong to their publishers; see each manifest for URLs.