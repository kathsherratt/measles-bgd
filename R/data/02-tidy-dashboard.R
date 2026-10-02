#!/usr/bin/env Rscript
#'
#' Tidy the DGHS platform dashboard into the canonical case series.
#'
#' Reads the raw vintages in data/dghs-dashboard.csv
#' (`R/data/01-fetch-dashboard.R`), keeps the latest vintage of each value, renames measures and divisions,
#' adds national totals and flags days the platform did not record normally.
#' Analysis reads data/dghs-cases.csv, not the raw file.
#'
#' The dashboard's Excel export calls `discharged` "Recovered" and omits
#' `serum_sent`.
#'
#' The platform launched on 26 April. Data from 15 March to 7 April were
#' loaded onto 7 April, and 2 to 5 April are empty (`docs/plan.md`, section
#' "Press releases against the dashboard"). The flag is rule-based on the date.
#'
#' Division-level rows come from the national call, district rows from the
#' per-division calls. National rows are the sum of divisions.
#'
#' Outputs (gitignored until publication terms are agreed):
#'   data/dghs-cases.csv         long: date, level, division, district,
#'                               measure, value, report_count, fetched_at, flag
#'   data/dghs-cases-checks.csv  one row per check and key; failures are
#'                               recorded, not corrected
#'
#' Usage:
#'     Rscript R/data/02-tidy-dashboard.R

suppressMessages(library(data.table))

IN <- here::here("data", "dghs-dashboard.csv")
OUT <- here::here("data", "dghs-cases.csv")
OUT_CHECKS <- here::here("data", "dghs-cases-checks.csv")

# Platform spelling to official spelling (division and district).
NAMES <- c(Barisal = "Barishal")

# Dashboard field names to measure names.
MEASURES <- c(suspected24h = "suspected", confirmed24h = "confirmed",
              suspectedDeath24h = "suspected_deaths",
              confirmedDeath24h = "confirmed_deaths",
              admitted24h = "admitted", discharged24h = "discharged",
              serumSent24h = "serum_sent")

# Days the platform did not record normally (docs/plan.md).
BACKFILL_DATE <- as.IDate("2026-04-07")
EMPTY_DATES <- as.IDate(c("2026-04-02", "2026-04-03", "2026-04-04",
                          "2026-04-05"))
FIRST_FULL_DATE <- as.IDate("2026-04-10")

# ----------------------------------------------------------------- read ----

raw <- fread(IN)

# Latest vintage of each value.
raw <- raw[order(fetched_at)][,
    .SD[.N], by = .(date, level, division, geography, measure)]

raw[, measure := MEASURES[measure]]
stopifnot(!anyNA(raw$measure))
raw[division %in% names(NAMES), division := NAMES[division]]
raw[geography %in% names(NAMES), geography := NAMES[geography]]

# ----------------------------------------------------------------- tidy ----

# `reportCount` belongs to the call, not to a row: the national call's count
# is national, and each division call's count is that division's. District
# rows carry their division's count (no count per district is published).
nat_reports <- raw[level == "division",
                   .(report_count = report_count[1]), by = date]
div_reports <- raw[level == "district",
                   .(report_count = report_count[1]), by = .(date, division)]

divs <- raw[level == "division",
    .(date, level, division, district = NA_character_, measure, value,
      fetched_at)]
divs <- merge(divs, div_reports, by = c("date", "division"), all.x = TRUE)
dists <- raw[level == "district",
    .(date, level, division, district = geography, measure, value,
      report_count, fetched_at)]
nat <- divs[, .(level = "national", division = NA_character_,
                district = NA_character_, value = sum(value),
                fetched_at = max(fetched_at)),
            by = .(date, measure)]
nat <- merge(nat, nat_reports, by = "date", all.x = TRUE)

cases <- rbind(nat, divs, dists, use.names = TRUE)
cases[, flag := NA_character_]
cases[date == BACKFILL_DATE, flag := "prelaunch_backfill"]
cases[date %in% EMPTY_DATES, flag := "prelaunch_empty"]
setcolorder(cases, c("date", "level", "division", "district", "measure",
                     "value", "report_count", "fetched_at", "flag"))
setorder(cases, date, level, division, district, measure)
fwrite(cases, OUT)
message("wrote ", OUT, ": ", nrow(cases), " rows, ",
        min(cases$date), " to ", max(cases$date))

# --------------------------------------------------------------- checks ----

# Districts sum to their division, per date and measure.
d_sum <- cases[level == "district",
               .(observed = sum(value)), by = .(date, division, measure)]
d_exp <- divs[, .(date, division, measure, expected = value)]
chk_sum <- merge(d_exp, d_sum, by = c("date", "division", "measure"),
                 all = TRUE)
chk_sum[, `:=`(check = "districts_sum_to_division",
               pass = !is.na(expected) & !is.na(observed) &
                   expected == observed)]

# No negative values (observed is the minimum; expected is the lower bound).
chk_neg <- cases[level != "national", .(
    check = "no_negative_values", expected = 0L,
    observed = min(value), pass = all(value >= 0L)
), by = .(date, division, measure)]

# No missing dates at division level from the first full day.
all_dates <- seq(FIRST_FULL_DATE, max(cases$date), by = "day")
have <- unique(divs[, .(date, division)])
grid <- CJ(date = all_dates, division = unique(divs$division))
grid <- merge(grid, have[, present := TRUE], by = c("date", "division"),
              all.x = TRUE)
chk_dates <- grid[, .(check = "no_missing_dates", date, division,
                      measure = NA_character_, expected = 1L,
                      observed = as.integer(!is.na(present)),
                      pass = !is.na(present))]

# Division report counts sum to the national report count.
chk_reports <- merge(nat_reports[, .(date, expected = report_count)],
                     div_reports[, .(observed = sum(report_count)), by = date],
                     by = "date", all = TRUE)
chk_reports[, `:=`(check = "division_reports_sum_to_national",
                   division = NA_character_, measure = "report_count",
                   pass = !is.na(expected) & !is.na(observed) &
                       expected == observed)]

cols <- c("check", "date", "division", "measure", "expected", "observed",
          "pass")
checks <- rbind(chk_sum[, ..cols], chk_neg[, ..cols], chk_dates[, ..cols],
                chk_reports[, ..cols])
setorder(checks, check, date, division, measure)
fwrite(checks, OUT_CHECKS)

summ <- checks[, .(n = .N, failed = sum(!pass)), by = check]
message("checks: ", paste0(summ$check, " ", summ$n - summ$failed, " pass/",
                           summ$failed, " fail", collapse = "; "))
