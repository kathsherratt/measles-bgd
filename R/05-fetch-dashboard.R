#!/usr/bin/env Rscript
#'
#' Fetch daily district-level counts from the DGHS measles monitoring platform.
#'
#' https://measles.dghs.gov.bd is the platform through which reporting units
#' (district civil surgeon offices and hospitals, about 94 a day) submit their
#' daily figures. Its public dashboard reads JSON from `/api/reports/summary`,
#' which takes `outbreakId`, `date`, and optionally `division`: without a
#' division it returns the eight divisions, with one it returns that
#' division's districts. This script asks for the same data the dashboard
#' shows, one date and division at a time, throttled.
#'
#' What it adds to the press releases:
#'   - districts, not only divisions;
#'   - serum samples sent to the lab, from May;
#'   - days with no press release;
#'   - the database's current values. Compared with the press releases
#'     (30 September), these differ only where DGHS moved a correction back
#'     to the day it belonged to: the back-fill of 15 March to 7 April onto
#'     7 April when the platform launched (26 April), the Rajshahi duplicate
#'     removal spread over April and early May, and a single 6-case fix on
#'     3 August. From June a published day never changes: backlog reporting
#'     is off and edits close at 14:32, so a late report counts on the day it
#'     arrives. Repeated runs will therefore rarely differ; they are kept to
#'     detect any change of practice, not to build a reporting triangle.
#' Cox's Bazar reports as one unit (the civil surgeon office), so camps cannot
#' be separated here.
#'
#' The `/api/reports/timeseries` endpoint ignores its date range and returns the
#' last 30 days only, so it is not used.
#'
#' Every response is kept verbatim under data/raw/dghs-dashboard/<fetched>/,
#' so a run can be re-tidied without refetching. The tidy output carries
#' `fetched_at` so vintages can be compared.
#'
#' Usage:
#'     Rscript R/05-fetch-dashboard.R [--from YYYY-MM-DD] [--to YYYY-MM-DD]
#'
#' Defaults: from 2026-04-01 to yesterday. A full run is about 1,600 requests;
#' the server takes about 6 seconds each, so a full run is 2 to 3 hours. Run it
#' detached, and use --from for incremental updates.

suppressMessages({
    library(data.table)
    library(httr2)
    library(jsonlite)
})

BASE <- "https://measles.dghs.gov.bd/api/reports/summary"
OUTBREAK <- "measles-2026"
DIVISIONS <- c("Barisal", "Chattogram", "Dhaka", "Khulna", "Mymensingh",
               "Rajshahi", "Rangpur", "Sylhet")

args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default) {
    i <- match(flag, args)
    if (is.na(i)) default else args[i + 1]
}
FROM <- as.IDate(arg("--from", "2026-04-01"))
TO <- as.IDate(arg("--to", as.character(Sys.Date() - 1)))

FETCHED <- format(Sys.time(), "%Y-%m-%dT%H%M")
RAW_DIR <- here::here("data", "raw", "dghs-dashboard", FETCHED)
OUT <- here::here("data", "dghs-dashboard.csv")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

# ----------------------------------------------------------------- http ----

get_summary <- function(date, division = NULL) {
    req <- request(BASE) |>
        req_url_query(outbreakId = OUTBREAK, date = format(date),
                      division = division) |>
        req_user_agent("measles-bgd (github.com/kathsherratt/measles-bgd)") |>
        req_retry(max_tries = 4, backoff = function(i) 2^i) |>
        req_throttle(capacity = 1, fill_time_s = 1)
    resp_body_string(req_perform(req))
}

#' One response as long rows. `level` is what the breakdown holds.
tidy <- function(txt, date, division) {
    x <- fromJSON(txt, simplifyVector = FALSE)
    rows <- lapply(names(x$breakdown), function(g) {
        v <- x$breakdown[[g]]
        data.table(geography = g, measure = names(v),
                   value = as.numeric(unlist(v)))
    })
    out <- rbindlist(rows)
    if (!nrow(out)) return(NULL)
    out[, `:=`(
        date = date,
        level = if (is.null(division)) "division" else "district",
        division = if (is.null(division)) geography else division,
        report_count = x$debug$reportCount %||% NA_integer_
    )]
    out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------- fetch ----

dates <- seq(FROM, TO, by = 1L)
message(length(dates), " dates, ", format(FROM), " to ", format(TO),
        "; raw to ", RAW_DIR)

rows <- list()
for (d in as.list(dates)) {
    d <- as.IDate(d)
    for (dv in c(list(NULL), as.list(DIVISIONS))) {
        tag <- if (is.null(dv)) "national" else dv
        path <- file.path(RAW_DIR, sprintf("%s_%s.json", format(d), tag))
        txt <- tryCatch(get_summary(d, dv), error = function(e) {
            message("  ! ", format(d), " ", tag, ": ", conditionMessage(e))
            NULL
        })
        if (is.null(txt)) next
        writeLines(txt, path)
        rows[[paste(d, tag)]] <- tidy(txt, d, dv)
    }
    if (mday(d) == 1L) message(format(d))
}

out <- rbindlist(rows)
out[, fetched_at := FETCHED]
setcolorder(out, c("date", "level", "division", "geography", "measure",
                   "value", "report_count", "fetched_at"))

# Append, so vintages accumulate in one file.
if (file.exists(OUT)) out <- rbind(fread(OUT), out, fill = TRUE)
fwrite(out, OUT)
message("wrote ", OUT, ": ", nrow(out), " rows, ",
        uniqueN(out$fetched_at), " vintage(s)")
