# Measles parameter register

A small literature-sourced register of measles parameters for the analysis of the 2026 Bangladesh outbreak. The epireview R package (mrc-ide) has no measles data, so rows follow a subset of epireview's `*_parameters.csv` schema, in case the register is contributed upstream later.

## Status: unreviewed

Rows P01 to P50 were extracted by an LLM (`extracted_by = "LLM, unreviewed"`), many from abstracts only (flagged in `parameter_notes`, quality C); rows marked "computed" were derived by the extractor from counts in the source.

Rows from P51 on go through a quote check: an LLM locates the passage and proposes a row in `proposals.csv` with the verbatim `quote` and `value_text` (the part holding the number); `R/parameters/02-check-proposals.py` keeps the row only if the quote is a span of the PDF page's text layer and `value_text` occurs once in it on number boundaries, then parses the value and bounds from `value_text` (`extracted_by = "LLM-located quote; value parsed by script; unreviewed"`). Failures go to `proposals-rejected.csv`. Every row still needs a person's check before use.

## Files

- `measles_parameters.csv`: one row per parameter estimate.
- `measles_articles.csv`: one row per source, with DOI, study type and what was and was not read, and `pdf_key`, the Zotero storage key of the PDF used for quote checks. Six sources were opened but yielded no extractable value (A06, A07, A24, A27, A28, A29); they are listed so the gap is visible.
- `proposals.csv`, `proposals-rejected.csv`: proposed rows with quotes, and those that failed the check.
- `priors.csv`: model priors built by `R/parameters/03-build-priors.R` from checked register rows only; each names its rows and derivation. `status = "draft"` until a person fills `reviewed_by`.

## Schema

Columns follow epireview names and order:

`id`, `article_id`, `pathogen`, `parameter_type`, `parameter_value`, `parameter_unit`, `parameter_value_type`, `parameter_uncertainty_type`, `parameter_uncertainty_lower_value`, `parameter_uncertainty_upper_value`, `distribution_type`, `distribution_par1_type`, `distribution_par1_value`, `distribution_par2_type`, `distribution_par2_value`, `population_country`, `population_location`, `population_age_min`, `population_age_max`, `population_sample_size`, `case_definition`, `method_disaggregated_by`, `parameter_notes`.

Three columns are ours and not in epireview:

| Column | Content |
|---|---|
| `source_location` | Where the number appears (abstract, table, text section) |
| `quality_flag` | A: systematic review, meta-analysis or large well-described study. B: single study, adequate methods. C: weak, old, indirect, abstract-only without full uncertainty, or preprint |
| `extracted_by` | How the value was obtained (see Status) |
| `quote`, `value_text`, `pdf_page` | The checked passage, the part of it holding the number, and the PDF page (rows from P51) |
| `via_article_id` | The source a value was taken from when the paper cited is not the one that estimated it (for example Marye 2026 using a value from Vink 2014) |

Conventions:

- `parameter_type` uses epireview's `parameter_type_full` vocabulary where a match exists (`inst/extdata/param_name.csv`): "Human delay - Exposure/Infection to Symptom Onset/Fever", "Human delay - generation time", "Human delay - serial interval", "Human delay - Symptom Onset/Fever to Death", "Severity - case fatality rate (CFR)", "Reproduction number (Basic R0)", "Risk factors".
- Labels marked "(provisional)" (admission to discharge, proportion of suspected cases confirmed, age of cases) have no epireview equivalent yet.
- Types with no epireview equivalent, used as provisional labels: "Vaccine effectiveness" (and "Vaccine effectiveness (relative)", "Vaccine effectiveness (mortality)"), "Seroconversion after MCV1", "Seroprevalence (maternal antibody)", "Duration of maternal immunity", "Treatment effect - vitamin A (mortality)". These would need agreeing with epireview maintainers.
- Ages are in years. `population_age_max` is blank where open-ended.
- Percentages are stored as numbers (3.2 means 3.2%). Relative measures (RR, OR) are unitless ratios.
- `method_disaggregated_by` holds the stratum a row describes (setting, age group, dose, comparison).

## How rows were found

Searches used the Europe PMC REST API (title and keyword queries by parameter), starting from the papers named in the brief (Lessler, Vink, Portnoy, Wolfson, Uzicanin and Zimmerman, Guerra, and the 2026 Bangladesh papers). Full text was read where open access through Europe PMC or PMC. Otherwise only the abstract was read. Direct fetches of publisher and PubMed pages mostly failed (paywalls, bot checks). Search was stopped after roughly an hour. Priority was given to low- and middle-income and South Asian sources.

## Coverage and gaps

Rows by parameter: incubation (2), generation time (1), serial interval (1), onset to death (1), CFR (18), risk factors (7), vaccine effectiveness and related (8), maternal antibody (5), vitamin A (3), R0 (4).

Not found in a source that was actually read:

- Fever onset to rash onset, admission to death, and length of stay.
- Serial interval or generation time with uncertainty or a fitted distribution (Vink and Klinkenberg abstracts give point values or ranges only).
- Exposure to rash-onset incubation period (Lessler measures exposure to first symptoms).
- CFR by malnutrition status, and any measles-specific RR for malnutrition.
- Numeric CFR values from Wolfson 2009 and R0 values from Guerra 2017 (abstracts contain none; full text not accessed).
- Bangladesh-specific R0 or transmission parameters for 2026. The 2026 Bangladesh sources found give crude counts, proportions and in-hospital CFR only. The Lancet comment and IJID commentary had no abstract available and were not read.
- Mahmud 2017 (Matlab CFR by model) has no numbers in its abstract and is worth reading in full.

## Known cautions

- Sbarra 2023 South Asia rows are regional, not Bangladesh-specific.
- The DRC onset-to-death median (27.5 days) includes late deaths beyond 31 days and rests on recall data.
- The Lessler median CI upper bound is 13.2 in the text and 13.3 in Table 3. The text value is recorded.
- R0 IQR values from Fu 2026 appear to be widths, not bounds, and are noted rather than entered as limits.
- Preprint rows (Pervez, Goutam, Kamrujjaman) are not peer reviewed.

## Screening the Measles Analytics Hub directory

`needs.csv` lists each model input with the step that uses it, how sensitive outputs are to it, the register rows that cover it, the gap, and a regular expression of search terms. It drives screening, so new sources are searched for what the models need rather than for what earlier searches happened to find.

Systematic review exported from MAH: https://www.measles-analytics.org/publications-and-literature 

`R/parameters/01-screen-directory.R` screens the directory export (`measles-analytics-directory.csv`, gitignored until reuse terms are checked; hash in `manifest-directory.csv`) without a language model: it drops theoretical model-analysis papers, matches the remaining titles, abstracts and keywords against `needs.csv`, and writes `directory-screen.csv` (one row per paper, no abstracts) and the counts at each step to `search-log.csv`. A match is a candidate for abstract screening, not an inclusion.
