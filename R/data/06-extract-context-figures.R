#!/usr/bin/env Rscript
#'
#' Extract candidate figures from the context documents, for a person to
#' confirm.
#'
#' Reads the text layer of each document listed in
#' data/manifest-context.csv (`R/data/04-fetch-context.R`) and records every
#' regular-expression match of a figure next to a keyword. No value is typed
#' or read by a language model: each `value` is parsed from the verbatim
#' `quote`, which is the sentence (or, for `quote_type = "line"`, the
#' physical line) that matched. A person ticks `confirmed_by` after checking
#' the quote against the source page. Patterns were designed by reading the
#' text; they carry no figures.
#'
#' A second route raises recall for the camps. A language model reads the
#' text layer and proposes quotes in data/camps-proposals.csv; it is never
#' the source of a number or date. A proposal is kept only if its quote is a
#' span of that page's text (whitespace squished, no other tidying) and its
#' `value_text` or `date_text` occurs once in the quote. The value or date is
#' then parsed here from that token. Kept rows have `quote_type = "proposed"`;
#' the rest go to data/camps-proposals-rejected.csv with a reason.
#'
#' Outputs:
#'   data/context-figures.csv  national and division-level measles cases by
#'                             age, sex and vaccination status (who_don,
#'                             who_searo, un_rco, unicef)
#'   data/camps-measles.csv    Rohingya camp measles figures (rohingya_health,
#'                             who_searo, un_rco; and proposals)
#'   data/camps-events.csv     camp response events, from proposals only
#'   data/camps-proposals-rejected.csv  proposals that failed the gate
#'
#' Columns: id (hash of doc_id, page, quote and indicator), source, doc_id,
#' published_date, page, indicator, value, unit, denominator (a case or child
#' count in the same sentence, else NA), geography (place names found in the
#' sentence, else "not stated"), period_text (date or week phrases in the
#' sentence), quote, quote_type (sentence, line or manual), confirmed_by,
#' review_note.
#'
#' Indicator vocabulary, context-figures.csv (unit pct unless stated):
#'   cases_age_under5_pct, cases_age_under2_pct, cases_age_under9m_pct,
#'   cases_age_under1y_pct   share of cases under that age
#'   cases_age_<lo>_<hi><y|m>_pct   share in an age band named in the
#'                           sentence, e.g. cases_age_1_14y_pct
#'   cases_sex_male_pct, cases_sex_female_pct
#'   cases_sex_ratio_mf      male to female ratio (unit ratio)
#'   cases_unvaccinated_pct, cases_zero_dose_pct,
#'   cases_undervaccinated_pct, cases_partially_vaccinated_pct,
#'   cases_one_dose_pct, cases_two_dose_pct, cases_unknown_vacc_pct
#'
#' Indicator vocabulary, camps-measles.csv (unit count unless stated):
#'   camp_suspected_cases, camp_confirmed_cases, camp_epilinked_cases,
#'   camp_total_cases (outbreak-related, confirmed plus epi-linked),
#'   camp_deaths, camp_admissions
#'   From proposals also: camp_lab_results, camp_outbreaks,
#'   camp_outbreaks_new, camp_rubella_confirmed, camp_cfr_pct,
#'   camp_incidence_annualised_per_million, camp_cases_age_<band>_pct,
#'   camp_isolation_beds, camp_sari_itc_count, camp_campaign_target,
#'   camp_campaign_vaccinated, camp_campaign_coverage_pct,
#'   camp_campaign_vitamin_a, camp_rcm_coverage_pct,
#'   camp_rcm_children_eligible, camp_routine_mr_doses, camp_chw_mobilised,
#'   host_campaign_vaccinated. Unit from the suffix (_pct, _per_million).
#'   Cumulative or period is not an indicator: `period` (cumulative, month,
#'   week, point) is proposed, and `as_of_date` is parsed from period_text.
#'
#' Event vocabulary, camps-events.csv: campaign_round, facility_opened,
#' isolation_beds, isolation_facility_designated, surveillance_change,
#' coordination, other. `event_date` is parsed from `date_text`, with
#' `date_precision` day or month; no date in the quote leaves it empty.
#'
#' camps-measles.csv adds `period`, `as_of_date` and `proposal_note` (the
#' proposer's note, kept apart from the reviewer's). Content that exists
#' only in charts or maps is listed as `quote_type = "needs_manual"`, with
#' no value, for a person to enter by hand.
#'
#' Re-running merges on `id`: rows with `confirmed_by` or `review_note`
#' filled, and hand-entered rows (`quote_type = "manual"`, entered by a
#' person where the text layer is garbled), are kept as they are; other
#' rows, proposals included, are regenerated. `review_note` holds the
#' reviewer's note, e.g. the case base ("lab-confirmed cases") or whether a
#' count is cumulative.
#'
#' Review decisions come from data/camps-review.csv (key, decision,
#' reviewed_by, reviewed_at, note), exported from the camp extract review
#' page and applied on every run, keyed on `id`: confirmed sets
#' `confirmed_by` and `review_note`; unsure sets `review_note` only;
#' rejected drops the row to camps-proposals-rejected.csv.
#'
#' Usage:
#'     Rscript R/data/06-extract-context-figures.R
#'
#' Limitations:
#'   - Precision over recall. Charts, images and multi-column highlight
#'     panels are garbled or absent in the text layer. The line pass picks up
#'     some of the panels (quote_type "line"); figures only in images are
#'     missed.
#'   - A percentage is paired with its nearest age or vaccination keyword
#'     (see `pair_pct()`); lists of several percentages can be mispaired, so
#'     check every quote.
#'   - Counts by age or sex, and numbers written as words above twenty, are
#'     not extracted. Cumulative and period counts are not distinguished.
#'   - SEARO bulletins cover several countries; sentences are kept only if
#'     the page mentions Bangladesh and the sentence names no other country.

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(purrr)
  library(tibble)
})

MANIFEST <- here::here("data", "manifest-context.csv")
OUT_FIGURES <- here::here("data", "context-figures.csv")
OUT_CAMPS <- here::here("data", "camps-measles.csv")
PROPOSALS <- here::here("data", "camps-proposals.csv")
OUT_EVENTS <- here::here("data", "camps-events.csv")
OUT_REJECTED <- here::here("data", "camps-proposals-rejected.csv")
REVIEW <- here::here("data", "camps-review.csv")

FIGURE_SOURCES <- c("who_don", "who_searo", "un_rco", "unicef")
CAMP_SOURCES <- c("rohingya_health", "who_searo", "un_rco")

MAX_QUOTE <- 500  # characters; longer sentences are cut around the match

# -------------------------------------------------------------- patterns ----

re <- function(x) regex(x, ignore_case = TRUE)

# Percentage: "79%", "81 per cent".
PCT <- "(\\d+(?:\\.\\d+)?)\\s?(?:%|per ?cent|percent)"

# Percentages that are not shares of cases.
PCT_EXCLUDE <- "CFR|case[- ]fatality|coverage|incidence|target|attack rate"

# Keywords for the pairing step. Each row is one indicator; the regex finds
# its mentions in a sentence. Age bands are named from the match (see
# `band_indicator()`).
BAND <- "(\\d{1,2})\\s?(?:to|-|–|and)\\s?(\\d{1,2})\\s?(years|months)"
KEYWORDS <- tribble(
  ~indicator, ~regex,
  "cases_age_under5_pct",
  paste0("\\bunder[- ](?:5|five)\\b(?![- ]?(?:months?|weeks?))",
         "|\\b(?:less than|below) (?:5|five) years",
         "|\\b0\\s?(?:-|–|to)\\s?4 years"),
  "cases_age_under2_pct",
  "\\b(?:under|below|less than)[- ](?:2|two) years",
  "cases_age_under9m_pct",
  "\\b(?:under|below|less than)[- ](?:9|nine) months",
  "cases_age_under1y_pct",
  "\\b(?:under|below|less than)[- ](?:1|one|12) (?:year|months)",
  "cases_age_band",
  paste0("\\b(?:aged?|ages|between) ", BAND),
  "cases_sex_female_pct", "\\b(?:females?|girls?)\\b",
  "cases_sex_male_pct", "\\b(?:males?|boys?)\\b",
  "cases_unvaccinated_pct",
  paste0("\\bunvaccinated\\b|\\bnot (?:been )?vaccinated\\b",
         "|\\bno (?:history of )?vaccination\\b"),
  "cases_zero_dose_pct", "\\bzero[- ]dose\\b",
  "cases_undervaccinated_pct", "\\bunder-?vaccinated\\b",
  "cases_partially_vaccinated_pct",
  "\\bpartially vaccinated\\b|\\bincompletely vaccinated\\b",
  "cases_one_dose_pct",
  "\\b(?:received )?(?:one|1|a single) dose\\b",
  "cases_two_dose_pct",
  "\\b(?:received )?(?:two|2) doses\\b|\\bfully vaccinated\\b",
  "cases_unknown_vacc_pct",
  paste0("\\bunknown vaccination status\\b",
         "|\\bvaccination status (?:was |is )?unknown\\b")
)

# Sentences must be about cases for the pct indicators (not coverage).
CASE_WORDS <- "\\b(?:cases?|patients?|deaths?|admissions?|infected)\\b"

SEARO_OTHER <- paste(
  "Maldives", "Nepal", "India\\b", "Indonesia", "Myanmar", "Thailand",
  "Timor", "Bhutan", "Sri Lanka", "DPR Korea", "Korea", "Afghanistan",
  "Pakistan", sep = "|"
)

# Documents with case definitions and protocols, not figures.
SKIP_DOCS <- "SOP"

CAMP_WORDS <- "Rohingya|\\bcamps?\\b|Cox.s Bazar|Bhasan Char|Ukhi?ya|Teknaf"
NATIONAL_WORDS <- paste0("countr(?:y)?-?wide|in Bangladesh|DGHS|HEOC|",
                         "national(?! polio)")
OTHER_DISEASE <- "cholera|diphtheria|dengue|chikungunya|COVID|\\bAWD\\b"

# Numbers: digits with comma or space thousands separators, decimals, or
# words (one to twenty) for parsing counts written out.
WORDS <- c(one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
           seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11,
           twelve = 12, thirteen = 13, fourteen = 14, fifteen = 15,
           sixteen = 16, seventeen = 17, eighteen = 18, nineteen = 19,
           twenty = 20)
NUM <- paste0(
  "(?<![\\d.,-])(?:\\d{1,3}(?:[,\\u00a0 ]\\d{3})+(?!\\d)",
  "|\\d+(?![.]\\d)|\\b(?:", paste(names(WORDS), collapse = "|"), ")\\b)"
)

# Camp count patterns. Group 1 is the number, group 2 an optional figure in
# brackets after a word number ("Ten (10)"), which takes precedence.
LAB <- paste0("(?:(?:were|was|are|had been|have been|being|newly|all|",
              "of which|which|became) )*")
# Number, optional bracketed repeat, as the start of most patterns.
N2 <- paste0("(", NUM, ")\\s+(?:\\((\\d+)\\)\\s+)?")
CAMP_PATTERNS <- tribble(
  ~indicator, ~regex,
  "camp_deaths",
  paste0(N2, "(?:(?:suspected|confirmed|related|measles-related|measles|",
         "laboratory-confirmed|lab-confirmed)\\s+){0,3}deaths?\\b"),
  "camp_confirmed_cases",
  paste0(N2, "(?:cases\\s+)?", LAB,
         "(?:(?:laboratory|lab|PCR)[- ])?(?:confirmed|positive)",
         "(?!(?:\\s+measles)?\\s+(?:outbreaks?|deaths?)",
         "|\\s+(?:rubella|diphtheria|cholera|dengue))"),
  "camp_epilinked_cases",
  paste0(N2, LAB, "(?:epidemiologically|epi)[- ]?linked"),
  "camp_suspected_cases",
  paste0(N2, "(?:new\\s+|reported\\s+)?suspected",
         "(?!(?:\\s+measles)?\\s+deaths?)"),
  "camp_total_cases",
  paste0("outbreak-related measles cases to (", NUM, ")()"),
  "camp_admissions",
  paste0(N2, "(?:measles\\s+)?(?:patients\\s+)?(?:were\\s+)?",
         "(?:hospital\\s+)?(?:admissions?|admitted)\\b"),
  "camp_admissions",
  paste0("admissions? (?:reached|totalled|of) (", NUM, ")()")
)

MONTH <- paste0("(?:January|February|March|April|May|June|July|August|",
                "September|October|November|December)")
DAY <- "\\d{1,2}(?:st|nd|rd|th)?"
PERIOD_PATTERNS <- c(
  paste0("(?:(?:as of|since|from|between|during|by|until|up to|in) )?",
         DAY, "(?:\\s?(?:-|–|to|and)\\s?", DAY, ")?\\s", MONTH,
         "(?:\\s\\d{4})?(?:\\s?(?:-|–|to|and)\\s?", DAY, "\\s", MONTH,
         "(?:\\s\\d{4})?)?"),
  paste0("(?:(?:as of|since|during|in) )?", MONTH, "\\s\\d{4}"),
  paste0("(?:epi(?:demiological)?[ -]?week|EW|ISO week|week)s?",
         "\\s\\d{1,2}(?:\\s?(?:-|–|to)\\s?\\d{1,2})?")
)

GEO_PATTERNS <- c(
  "Rohingya(?: refugee)? camps?", "Cox.s Bazar", "Bhasan Char", "Ukhi?ya",
  "Teknaf", "\\bcamps?\\b", "Camp \\d+\\w*",
  "Barishal|Barisal", "Chattogram|Chittagong", "Dhaka", "Khulna",
  "Mymensingh", "Rajshahi", "Rangpur", "Sylhet", "Bangladesh"
)

# ------------------------------------------------------------- helpers ----

# Why: the PDFs break lines mid-sentence, and bullets are the only
# sentence boundary in highlight lists, so bullets are made explicit first.
split_sentences <- function(x) {
  x |>
    str_replace_all("&ndash;|&mdash;", "–") |>
    str_replace_all("[•▪●◦]|(?<=\\s)o(?=\\s\\d)", "\u0001") |>
    str_replace_all("\\s+", " ") |>
    str_split("\u0001|(?<=[.!?]|[.!?]\\d)\\s+(?=[A-Z(\\[])") |>
    unlist() |>
    str_squish() |>
    keep(\(s) nchar(s) > 0)
}

# One row per page, with sentence and line units. `prev` is the preceding
# unit, used only to check that a sentence is about measles.
read_units <- function(path, source, doc_id) {
  full <- here::here(path)
  pages <- if (str_detect(path, "\\.pdf$")) {
    tryCatch(pdftools::pdf_text(full), error = \(e) character())
  } else {
    paste(readLines(full, warn = FALSE), collapse = "\n")
  }
  map_dfr(seq_along(pages), \(p) {
    sents <- split_sentences(pages[[p]])
    lines <- pages[[p]] |>
      str_replace_all("&ndash;|&mdash;", "–") |>
      str_split("\n") |>
      unlist() |>
      str_squish()
    lines <- lines[nchar(lines) > 0]
    bind_rows(
      tibble(text = sents, quote_type = "sentence"),
      tibble(text = lines, quote_type = "line")
    ) |>
      group_by(quote_type) |>
      mutate(prev = lag(text, default = "")) |>
      ungroup() |>
      mutate(page = p, page_text = pages[[p]])
  }) |>
    mutate(source = source, doc_id = doc_id)
}

parse_num <- function(x) {
  x <- str_to_lower(x)
  w <- unname(WORDS[x])
  ifelse(!is.na(w), w, suppressWarnings(as.numeric(str_remove_all(
    x, "[^0-9.]"))))
}

# All matches of several patterns joined with "; ", or `none`.
collect_matches <- function(text, patterns, none = NA_character_) {
  hits <- map(patterns, \(p) str_extract_all(text, re(p))[[1]]) |>
    unlist() |>
    unique() |>
    str_squish()
  if (length(hits) == 0) none else paste(hits, collapse = "; ")
}

# First count in the sentence that is not the value itself and is not a
# "total of N cases" phrase (which restates the value).
find_denominator <- function(text, value) {
  m <- str_match_all(
    text,
    re(paste0("(?<!total )(?<!number )(?:out of|of|among|from) (?:the )?(",
              NUM, ")\\s(?:suspected |reported |measles |confirmed )*",
              "(?:cases|children|patients|samples|lab reports)"))
  )[[1]]
  if (nrow(m) == 0) return(NA_real_)
  d <- parse_num(m[, 2])
  d <- d[!is.na(d) & d != value]
  if (length(d) == 0) NA_real_ else d[[1]]
}

make_quote <- function(text, start, end) {
  if (nchar(text) <= MAX_QUOTE) return(text)
  from <- max(1, start - MAX_QUOTE %/% 2)
  to <- min(nchar(text), end + MAX_QUOTE %/% 2)
  paste0(if (from > 1) "…" else "", str_sub(text, from, to),
         if (to < nchar(text)) "…" else "")
}

band_indicator <- function(x) {
  m <- str_match(x, re(BAND))
  paste0("cases_age_", m[, 2], "_", m[, 3], str_sub(m[, 4], 1, 1), "_pct")
}

# Pair each age, sex or vaccination keyword with a percentage in the same
# sentence. Reporting styles differ ("79% were under 5", "under 5 (79%)"),
# so candidate pairs are scored and assigned greedily, nearest first:
#   - a percentage directly before the keyword ("72 per cent zero-dose")
#   - a percentage after the keyword within 70 characters
#   - a percentage before the keyword within 70 characters
# A pair is dropped if another percentage or keyword lies between them, or
# the gap contains "including" (which starts a sub-group), or the percentage
# is a CFR, coverage or similar.
pair_pct <- function(text) {
  loc <- function(pattern) {
    m <- str_locate_all(text, re(pattern))[[1]]
    if (nrow(m) == 0) return(tibble(start = integer(), end = integer()))
    tibble(start = m[, "start"], end = m[, "end"])
  }
  kw <- pmap_dfr(KEYWORDS, \(indicator, regex) {
    loc(regex) |> mutate(indicator = indicator)
  })
  pc <- loc(PCT)
  if (nrow(kw) == 0 || nrow(pc) == 0) return(NULL)
  kw <- kw |> mutate(k = row_number(), kw_text = str_sub(text, start, end))
  pc <- pc |>
    mutate(p = row_number(), pct_text = str_sub(text, start, end),
           value = as.numeric(str_match(pct_text, re(PCT))[, 2]),
           around = str_sub(text, pmax(1, start - 25),
                            pmin(nchar(text), end + 25)),
           excluded = str_detect(around, re(PCT_EXCLUDE)))
  pairs <- crossing(kw |> rename(k_start = start, k_end = end),
                    pc |> rename(p_start = start, p_end = end))
  pairs <- pairs |>
    filter(!excluded, p_end < k_start | p_start > k_end) |>
    mutate(
      dir = if_else(p_end < k_start, "back", "fwd"),
      gap_start = if_else(dir == "back", p_end + 1L, k_end + 1L),
      gap_end = if_else(dir == "back", k_start - 1L, p_start - 1L),
      gap = str_sub(text, gap_start, gap_end),
      gap_len = nchar(gap),
      score = case_when(
        dir == "back" & gap_len <= 12 ~ gap_len,
        dir == "fwd" ~ 20 + gap_len,
        TRUE ~ 40 + gap_len
      )
    ) |>
    filter(gap_len <= if_else(score < 20, 12L, 70L),
           !str_detect(gap, re("including|of whom|of which")))
  if (nrow(pairs) == 0) return(NULL)
  # Another percentage or keyword inside the gap blocks the pair.
  blocked <- pmap_lgl(
    list(pairs$gap_start, pairs$gap_end, pairs$p, pairs$k), \(gs, ge, p, k) {
      any(pc$p != p & pc$start >= gs & pc$end <= ge) ||
        any(kw$k != k & kw$start >= gs & kw$end <= ge)
    })
  pairs <- pairs[!blocked, ] |> arrange(score)
  used_p <- integer()
  used_k <- integer()
  keep_rows <- logical(nrow(pairs))
  for (i in seq_len(nrow(pairs))) {
    if (!(pairs$p[i] %in% used_p) && !(pairs$k[i] %in% used_k)) {
      keep_rows[i] <- TRUE
      used_p <- c(used_p, pairs$p[i])
      used_k <- c(used_k, pairs$k[i])
    }
  }
  pairs[keep_rows, ] |>
    mutate(
      indicator = if_else(indicator == "cases_age_band",
                          band_indicator(kw_text), indicator),
      m_start = pmin(k_start, p_start), m_end = pmax(k_end, p_end)
    ) |>
    select(indicator, value, m_start, m_end)
}

# Sex ratio ("male to female ratio of 1.2").
find_ratio <- function(text) {
  m <- str_match_all(
    text, re("male[- ]to[- ]female ratio(?: of| was| is)? (\\d+(?:\\.\\d+)?)")
  )[[1]]
  if (nrow(m) == 0) return(NULL)
  pos <- str_locate_all(
    text, re("male[- ]to[- ]female ratio(?: of| was| is)? (\\d+(?:\\.\\d+)?)")
  )[[1]]
  tibble(indicator = "cases_sex_ratio_mf", value = as.numeric(m[, 2]),
         m_start = pos[, "start"], m_end = pos[, "end"], unit = "ratio")
}

# Camp counts by pattern.
find_camp_counts <- function(text) {
  pmap_dfr(CAMP_PATTERNS, \(indicator, regex) {
    pos <- str_locate_all(text, re(regex))[[1]]
    if (nrow(pos) == 0) return(NULL)
    m <- str_match_all(text, re(regex))[[1]]
    tibble(indicator = indicator,
           value = ifelse(!is.na(m[, 3]) & nzchar(m[, 3]),
                          as.numeric(m[, 3]), parse_num(m[, 2])),
           m_start = pos[, "start"], m_end = pos[, "end"], unit = "count")
  })
}

# ------------------------------------------------------------ extract ----

# Returns one row per candidate for a unit (sentence or line).
extract_unit <- function(u, kind) {
  text <- u$text
  ctx <- paste(u$prev, text)
  if (kind == "figures") {
    if (!str_detect(text, re(CASE_WORDS))) return(NULL)
    if (u$source == "who_searo") {
      if (!str_detect(u$page_text, "Bangladesh") ||
            str_detect(text, SEARO_OTHER)) return(NULL)
      if (!str_detect(ctx, re("measles"))) return(NULL)
    }
    pcts <- pair_pct(text)
    if (!is.null(pcts)) pcts <- mutate(pcts, unit = "pct")
    hits <- bind_rows(pcts, find_ratio(text))
  } else {
    if (str_detect(text, re(paste(OTHER_DISEASE, "definition", sep = "|")))) {
      return(NULL)
    }
    if (!str_detect(ctx, re("measles"))) return(NULL)
    camp <- str_detect(text, re(CAMP_WORDS))
    # A line can sit under a national sentence that starts on the line above.
    national <- str_detect(if (u$quote_type == "line") ctx else text,
                           re(NATIONAL_WORDS))
    # The health bulletin is about the camps unless a sentence says it is
    # reporting the country; other sources must name the camps.
    ok <- if (u$source == "rohingya_health") camp || !national else camp
    if (!ok) return(NULL)
    hits <- find_camp_counts(text)
  }
  if (is.null(hits) || nrow(hits) == 0) return(NULL)
  hits |>
    mutate(
      source = u$source, doc_id = u$doc_id, page = u$page,
      denominator = map_dbl(value, \(v) find_denominator(text, v)),
      geography = collect_matches(text, GEO_PATTERNS, "not stated"),
      period_text = collect_matches(text, PERIOD_PATTERNS),
      quote = map2_chr(m_start, m_end, \(s, e) make_quote(text, s, e)),
      quote_type = u$quote_type
    ) |>
    select(-m_start, -m_end)
}

extract_doc <- function(row, kind) {
  units <- read_units(row$path, row$source, row$doc_id)
  if (nrow(units) == 0) return(NULL)
  res <- units |>
    group_split(row_number()) |>
    map_dfr(\(u) extract_unit(u, kind))
  if (nrow(res) == 0) return(NULL)
  # The line pass repeats most sentence matches; keep a line only if the
  # sentence pass did not find the same page, indicator and value.
  res |>
    mutate(key = paste(page, indicator, value)) |>
    arrange(quote_type != "sentence") |>
    distinct(key, quote, .keep_all = TRUE) |>
    group_by(key) |>
    filter(quote_type == "sentence" | !any(quote_type == "sentence")) |>
    ungroup() |>
    select(-key) |>
    mutate(published_date = row$published_date)
}

# --------------------------------------------------------------- merge ----

COLS <- c("id", "source", "doc_id", "published_date", "page", "indicator",
          "value", "unit", "denominator", "geography", "period_text",
          "quote", "quote_type", "confirmed_by", "review_note")

finish <- function(x) {
  if (is.null(x) || nrow(x) == 0) {
    return(tibble(!!!set_names(rep(list(character()), length(COLS)), COLS)))
  }
  x |>
    mutate(
      id = map_chr(paste(doc_id, page, quote, indicator), rlang::hash) |>
        str_sub(1, 12),
      confirmed_by = NA_character_,
      review_note = NA_character_
    ) |>
    distinct(id, .keep_all = TRUE) |>
    select(all_of(COLS))
}

# Rows a person has confirmed or annotated, and hand-entered rows
# (`quote_type = "manual"`), are never overwritten.
merge_confirmed <- function(new, path) {
  if (!file.exists(path)) return(new)
  old <- read_csv(path, col_types = cols(.default = col_character()),
                  show_col_types = FALSE)
  if (!"review_note" %in% names(old)) old$review_note <- NA_character_
  old <- old |>
    filter((!is.na(confirmed_by) & nzchar(confirmed_by)) |
             (!is.na(review_note) & nzchar(review_note)) |
             quote_type %in% "manual")
  new_cols <- new |>
    mutate(across(everything(), as.character))
  bind_rows(old, new_cols |> filter(!id %in% old$id)) |>
    mutate(across(any_of(c("value", "denominator")), as.numeric),
           page = as.integer(page))
}

# Decisions from the review page. Rows the reviewer rejected are returned
# as an attribute, for the rejected file.
apply_review <- function(x, review) {
  r <- review |>
    filter(key %in% x$id) |>
    mutate(note = na_if(note, ""))
  out <- x |>
    left_join(r, by = c("id" = "key")) |>
    mutate(
      confirmed_by = if_else(decision %in% "confirmed", reviewed_by,
                             confirmed_by),
      review_note = case_when(
        decision %in% "confirmed" ~ coalesce(note, review_note),
        decision %in% "unsure" ~ paste0("unsure", if_else(
          is.na(note), "", paste0(": ", note))),
        TRUE ~ review_note
      )
    )
  kept <- out |>
    filter(!decision %in% "rejected") |>
    select(all_of(names(x)))
  attr(kept, "rejected") <- out |> filter(decision %in% "rejected")
  kept
}

# ----------------------------------------------------------- proposals ----

# First number in a token as written: digits with thousands commas and
# decimals, or a word ("Twelve newly", "two (2) related", "CFR-0.6%").
FIRST_NUM <- paste0("\\d+(?:,\\d{3})*(?:\\.\\d+)?|\\b(?:",
                    paste(names(WORDS), collapse = "|"), ")\\b")
first_number <- function(x) parse_num(str_extract(x, re(FIRST_NUM)))

# First date in a phrase: "26 April", "10 & 11 May", "April 26", "1 August
# 2026", or a month alone ("July 2026", "As of July"). Year defaults to 2026.
parse_date <- function(x) {
  none <- list(date = as.Date(NA), precision = NA_character_)
  if (is.na(x) || !nzchar(x)) return(none)
  ymd_or_na <- function(y, m, d) {
    as.Date(sprintf("%s-%02d-%02d", coalesce(y, "2026"),
                    match(str_to_title(m), month.name), as.integer(d)))
  }
  m <- str_match(x, re(paste0(
    "(\\d{1,2})(?:st|nd|rd|th)?(?:\\s?(?:&|and|-|–|to)\\s?\\d{1,2})?\\s(",
    MONTH, ")(?:,?\\s(\\d{4}))?")))
  if (!is.na(m[1, 1])) {
    return(list(date = ymd_or_na(m[1, 4], m[1, 3], m[1, 2]),
                precision = "day"))
  }
  m <- str_match(x, re(paste0("(", MONTH, ")\\s(\\d{1,2})\\b(?:,?\\s(\\d{4}))?")))
  if (!is.na(m[1, 1])) {
    return(list(date = ymd_or_na(m[1, 4], m[1, 2], m[1, 3]),
                precision = "day"))
  }
  m <- str_match(x, re(paste0("(", MONTH, ")(?:\\s(\\d{4}))?")))
  if (!is.na(m[1, 1])) {
    return(list(date = ymd_or_na(m[1, 3], m[1, 2], 1), precision = "month"))
  }
  none
}

# The date a figure refers to: the day given, or the end of a month given
# alone ("In May 2026", "As of July"). Weeks ("EW 18") are left empty.
as_of_date <- function(period_text) {
  map(period_text, parse_date) |>
    map_chr(\(d) {
      if (is.na(d$date)) return(NA_character_)
      if (d$precision == "month") {
        d$date <- seq(d$date, by = "month", length.out = 2)[2] - 1
      }
      format(d$date)
    })
}

page_texts <- function(path) {
  full <- here::here(path)
  pages <- if (str_detect(path, "\\.pdf$")) {
    tryCatch(pdftools::pdf_text(full), error = \(e) character())
  } else {
    paste(readLines(full, warn = FALSE), collapse = "\n")
  }
  str_squish(pages)
}

# The gate. A proposal is kept only if its quote is a span of the page text
# and its token occurs once in the quote; there is no exemption route.
check_proposals <- function(path) {
  p <- read_csv(path, col_types = cols(.default = col_character()),
                show_col_types = FALSE) |>
    mutate(page = as.integer(page),
           across(c(value_text, date_text, period_text), \(x) na_if(x, "")))
  texts <- manifest |>
    filter(doc_id %in% p$doc_id) |>
    mutate(pages = map(path, page_texts)) |>
    select(source, doc_id, published_date, pages)
  p |>
    left_join(texts, by = "doc_id") |>
    mutate(
      quote = str_squish(quote),
      page_text = map2_chr(pages, page, \(x, i) {
        if (is.null(x) || i > length(x)) NA_character_ else x[[i]]
      }),
      token = coalesce(value_text, date_text),
      value = if_else(table == "figure", first_number(value_text), NA_real_),
      reason = case_when(
        table == "needs_manual" ~ NA_character_,
        is.na(source) ~ "document not in manifest",
        is.na(page_text) ~ "page not in document",
        !str_detect(page_text, fixed(quote)) ~
          "quote is not a span of the page text",
        table == "figure" & is.na(value_text) ~ "no value_text",
        !is.na(token) & str_count(quote, fixed(token)) != 1 ~
          "token does not occur exactly once in the quote",
        !is.na(period_text) & !str_detect(quote, fixed(period_text)) ~
          "period_text not in the quote",
        table == "figure" & is.na(value) ~ "no number in value_text",
        TRUE ~ NA_character_
      )
    ) |>
    select(-pages)
}

# Figures from accepted proposals, in the camps-measles.csv layout. The id
# adds value_text, since one quote can carry several figures.
proposed_figures <- function(p) {
  p |>
    filter(table == "figure") |>
    transmute(
      id = map_chr(paste(doc_id, page, quote, indicator, value_text),
                   rlang::hash) |> str_sub(1, 12),
      source, doc_id, published_date, page, indicator, value,
      unit = case_when(str_detect(indicator, "_pct$") ~ "pct",
                       str_detect(indicator, "_per_million$") ~ "per_million",
                       TRUE ~ "count"),
      denominator = NA_real_, geography = place_raw, period_text, quote,
      quote_type = "proposed", confirmed_by = NA_character_,
      review_note = NA_character_, period = na_if(period, ""),
      proposal_note = na_if(note, ""), value_text
    )
}

needs_manual <- function(p) {
  p |>
    filter(table == "needs_manual") |>
    transmute(
      id = map_chr(paste(doc_id, page, quote), rlang::hash) |> str_sub(1, 12),
      source, doc_id, published_date, page, indicator = NA_character_,
      value = NA_real_, unit = NA_character_, geography = place_raw,
      # The panel to read, before `quote` is emptied: it is not a quote
      proposal_note = paste0(quote, ". ", note),
      quote = NA_character_, quote_type = "needs_manual"
    )
}

proposed_events <- function(p) {
  p |>
    filter(table == "event") |>
    mutate(parsed = map(date_text, parse_date)) |>
    transmute(
      id = map_chr(paste(doc_id, page, quote, event, date_text, facility_raw),
                   rlang::hash) |> str_sub(1, 12),
      source, doc_id, published_date, page, event,
      event_date = map_chr(parsed, \(d) format(d$date)) |> na_if("NA"),
      date_precision = map_chr(parsed, "precision"),
      date_text, place_raw, facility_raw = na_if(facility_raw, ""), quote,
      quote_type = "proposed", proposal_note = na_if(note, ""),
      confirmed_by = NA_character_, review_note = NA_character_
    )
}

write_out <- function(x, path) {
  x |>
    arrange(published_date, doc_id, page) |>
    write_csv(path, na = "")
}

# ----------------------------------------------------------------- run ----

manifest <- read_csv(MANIFEST, col_types = cols(.default = col_character()),
                     show_col_types = FALSE)

run <- function(sources, kind) {
  docs <- manifest |>
    filter(source %in% sources, !str_detect(doc_id, SKIP_DOCS))
  map_dfr(seq_len(nrow(docs)), \(i) extract_doc(docs[i, ], kind))
}

figures <- run(FIGURE_SOURCES, "figures") |> finish()
camps <- run(CAMP_SOURCES, "camps") |> finish()

figures <- merge_confirmed(figures, OUT_FIGURES)
camps <- merge_confirmed(camps, OUT_CAMPS)

# Proposals: a kept (confirmed) version of a proposal is already in `camps`
# by id; any other proposal giving a figure the regex already found is not
# added twice.
checked <- check_proposals(PROPOSALS)
accepted <- checked |> filter(is.na(reason))
stopifnot(
  all(str_detect(accepted$page_text[accepted$table != "needs_manual"],
                 fixed(accepted$quote[accepted$table != "needs_manual"]))),
  !anyNA(accepted$value[accepted$table == "figure"])
)
prop_figures <- proposed_figures(accepted) |>
  filter(!id %in% camps$id)
seen <- camps |>
  transmute(key = paste(doc_id, page, indicator, value), seen_id = id)
dupes <- prop_figures |>
  mutate(key = paste(doc_id, page, indicator, value)) |>
  inner_join(seen, by = "key", multiple = "first")
prop_figures <- prop_figures |> filter(!id %in% dupes$id)
camps <- bind_rows(camps, select(prop_figures, -value_text),
                   needs_manual(accepted) |> filter(!id %in% camps$id)) |>
  mutate(as_of_date = as_of_date(period_text))

events <- merge_confirmed(proposed_events(accepted), OUT_EVENTS)

review <- read_csv(REVIEW, col_types = cols(.default = col_character()),
                   show_col_types = FALSE)
camps <- apply_review(camps, review)
events <- apply_review(events, review)
reviewed_out <- bind_rows(
  attr(camps, "rejected") |> mutate(table = if_else(
    quote_type %in% "needs_manual", "needs_manual", "figure")),
  attr(events, "rejected") |> mutate(table = "event")
) |>
  transmute(doc_id, page = as.integer(page), table, indicator, event,
            quote = coalesce(quote, proposal_note),
            reason = paste("rejected on review", reviewed_at))

rejected <- bind_rows(
  checked |> filter(!is.na(reason)),
  checked |>
    semi_join(dupes, by = c("doc_id", "page", "indicator", "value_text")) |>
    left_join(select(dupes, doc_id, page, indicator, value_text, seen_id),
              by = c("doc_id", "page", "indicator", "value_text")) |>
    mutate(reason = paste("already extracted as", seen_id))
) |>
  select(doc_id, page, table, indicator, event, value_text, date_text,
         quote, reason) |>
  bind_rows(reviewed_out)

write_out(figures, OUT_FIGURES)
write_out(camps, OUT_CAMPS)
write_out(events, OUT_EVENTS)
write_csv(rejected, OUT_REJECTED, na = "")

message("Candidates by source and indicator")
for (x in list(c("context-figures.csv", "figures"),
               c("camps-measles.csv", "camps"))) {
  d <- get(x[[2]])
  message("\n", x[[1]], ": ", nrow(d), " rows")
  print(count(d, source, indicator), n = Inf)
}
message("\nProposals by document: added, already extracted, rejected, ",
        "needing manual entry")
checked |>
  mutate(outcome = case_when(
    table == "needs_manual" ~ "needs_manual",
    !is.na(reason) ~ "rejected",
    paste(doc_id, page, indicator, value_text) %in%
      paste(dupes$doc_id, dupes$page, dupes$indicator, dupes$value_text) ~
      "already_extracted",
    TRUE ~ "added"
  )) |>
  count(doc_id, outcome) |>
  pivot_wider(names_from = outcome, values_from = n, values_fill = 0) |>
  print(n = Inf)
