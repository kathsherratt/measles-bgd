#!/usr/bin/env Rscript
#'
#' Screen the Measles Analytics Hub directory for papers likely to report
#' the parameters the models need.
#'
#' Reads the directory export (data/parameters/measles-analytics-directory.csv,
#' saved from https://www.measles-analytics.org/directory; hash in
#' manifest-directory.csv) and the list of model inputs
#' (data/parameters/needs.csv). Each need carries a regular expression; a
#' paper matches a need if its title, abstract or keywords match. No
#' language model is used. This is a recall-first pre-filter: matches are
#' candidates for abstract screening, not inclusions.
#'
#' Flags:
#'   theoretical  theme "Theoretical modelling", or methods terms that mark
#'                analysis of a model rather than estimation from data
#'                (fractional order, Caputo, Lyapunov, stability analysis).
#'                Their parameter values are assumed or taken from earlier
#'                papers, so they are not screened further.
#'   setting      South Asia, humanitarian or LMIC terms found in the text.
#'   keep         at least one need matched and not theoretical.
#'   score        2 per high-sensitivity need, 1 per other need, plus 2 for
#'                a South Asian setting and 1 for humanitarian or LMIC. Used
#'                only to order the abstract screen.
#'
#' Outputs:
#'   data/parameters/directory-screen.csv  one row per paper: paper_id, doi, title,
#'                                         year, theme, needs, setting,
#'                                         theoretical, keep, score (no
#'                                         abstracts)
#'   data/parameters/search-log.csv        counts in and out at each step,
#'                                         rows for this source replaced
#'
#' Usage:
#'     Rscript R/parameters/01-screen-directory.R
#'
#' Limitations:
#'   - Abstract-level matching: a parameter reported only in the full text
#'     is missed, and broad terms (admitted, mortality rate) over-match.
#'   - 12 papers have no abstract and match on title and keywords only.
#'   - Papers are keyed by DOI, or by lower-cased title where the DOI is
#'     blank. Entries listed twice under one DOI (online and print years)
#'     are kept once, with the earlier year.

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(purrr)
})

DIRECTORY <- here::here("data", "parameters", "measles-analytics-directory.csv")
NEEDS <- here::here("data", "parameters", "needs.csv")
OUT_SCREEN <- here::here("data", "parameters", "directory-screen.csv")
SEARCH_LOG <- here::here("data", "parameters", "search-log.csv")
SOURCE <- "Measles Analytics Hub directory, export 2026-10-03"

THEORETICAL <- paste(
  "fractional[- ]order", "fractional (derivative|model|calculus)", "caputo",
  "atangana", "lyapunov", "stability analysis", "homotopy", "bifurcation",
  "fractal", sep = "|")
SETTINGS <- c(
  south_asia = paste("bangladesh", "india", "pakistan", "nepal", "bhutan",
                     "sri lanka", "afghanistan", "myanmar", "south asia",
                     "rohingya", sep = "|"),
  humanitarian = "refugee|displaced|humanitarian|\\bcamps?\\b|conflict",
  lmic = paste("low[- ]and middle[- ]income", "\\blmics?\\b",
               "low[- ]income", "sub-saharan", "africa", sep = "|")
)

match_any <- function(text, pattern) {
  str_detect(text, regex(pattern, ignore_case = TRUE))
}

# ------------------------------------------------------------------ read ----

directory <- read_csv(DIRECTORY, col_types = cols(.default = col_character()),
                      show_col_types = FALSE) |>
  mutate(text = str_squish(paste(title, coalesce(abstract, ""),
                                 coalesce(keywords, ""))),
         paper_id = coalesce(str_to_lower(str_squish(doi)),
                             paste0("title:", str_to_lower(str_squish(title)))))
n_export <- nrow(directory)
directory <- directory |>
  arrange(year) |>
  distinct(paper_id, .keep_all = TRUE)
needs <- read_csv(NEEDS, col_types = cols(.default = col_character()),
                  show_col_types = FALSE)

# --------------------------------------------------------------- screen ----

need_hits <- needs |>
  select(need_id, sensitivity, terms) |>
  pmap_dfr(\(need_id, sensitivity, terms) {
    tibble(paper_id = directory$paper_id, need_id = need_id, sensitivity = sensitivity,
           hit = match_any(directory$text, terms))
  }) |>
  filter(hit)

setting_hits <- imap_dfr(SETTINGS, \(pattern, setting) {
  tibble(paper_id = directory$paper_id, setting = setting,
         hit = match_any(directory$text, pattern))
}) |>
  filter(hit)

screen <- directory |>
  transmute(paper_id, doi, title, year, theme, journal,
            theoretical = theme %in% "Theoretical modelling" |
              match_any(text, THEORETICAL)) |>
  left_join(need_hits |>
              group_by(paper_id) |>
              summarise(needs = paste(need_id, collapse = "; "),
                        need_score = sum(if_else(sensitivity == "high", 2, 1))),
            by = "paper_id") |>
  left_join(setting_hits |>
              group_by(paper_id) |>
              summarise(setting = paste(setting, collapse = "; ")),
            by = "paper_id") |>
  mutate(
    keep = !is.na(needs) & !theoretical,
    score = coalesce(need_score, 0) +
      2 * str_detect(coalesce(setting, ""), "south_asia") +
      str_detect(coalesce(setting, ""), "humanitarian|lmic"),
    score = if_else(keep, score, 0)
  ) |>
  select(-need_score) |>
  arrange(desc(keep), desc(score), year)

stopifnot(!anyDuplicated(screen$paper_id), nrow(screen) == nrow(directory))

# ------------------------------------------------------------------ log ----

log <- tribble(
  ~source, ~step, ~rule, ~n_in, ~n_out,
  SOURCE, "export", "all themes, all years", n_export, n_export,
  SOURCE, "deduplicate", "same DOI, or same title where DOI is blank",
  n_export, nrow(directory),
  SOURCE, "drop theoretical",
  "theme Theoretical modelling or model-analysis terms",
  nrow(screen), sum(!screen$theoretical),
  SOURCE, "match a need",
  "title, abstract or keywords match a needs.csv pattern",
  sum(!screen$theoretical), sum(screen$keep)
) |>
  mutate(run_date = format(Sys.Date()), .before = 1)
if (file.exists(SEARCH_LOG)) {
  log <- read_csv(SEARCH_LOG, col_types = cols(.default = col_character()),
                  show_col_types = FALSE) |>
    filter(source != SOURCE) |>
    bind_rows(mutate(log, across(everything(), as.character)))
}

write_csv(screen, OUT_SCREEN, na = "")
write_csv(log, SEARCH_LOG, na = "")

# -------------------------------------------------------------- summary ----

message(n_export, " entries; ", nrow(directory), " papers; ", sum(screen$theoretical),
        " theoretical; ", sum(screen$keep), " kept")
message("\nKept papers by need, and those with a South Asian setting")
need_hits |>
  semi_join(filter(screen, keep), by = "paper_id") |>
  left_join(select(screen, paper_id, setting), by = "paper_id") |>
  group_by(need_id) |>
  summarise(kept = n(),
            south_asia = sum(str_detect(coalesce(setting, ""), "south_asia"))) |>
  right_join(select(needs, need_id, parameter, sensitivity), by = "need_id") |>
  mutate(across(c(kept, south_asia), \(x) coalesce(x, 0L))) |>
  select(need_id, sensitivity, kept, south_asia, parameter) |>
  print(n = Inf)
