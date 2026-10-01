#!/usr/bin/env Rscript
#'
#' Fetch WHO provisional monthly measles and rubella surveillance counts for
#' Bangladesh.
#'
#' WHO publishes the monthly case-based surveillance counts that member states
#' report, by country, year, month and final classification, from 2012, as one
#' spreadsheet on the Immunization Data portal (table 404, "epi curve data").
#' For Bangladesh it gives the months before the DGHS daily series starts on
#' 2 April 2026, and a baseline for earlier years.
#'
#' These counts come from the EPI case-based surveillance system (the case
#' investigation forms), not from the hospital reporting behind the DGHS press
#' releases, so the two are not expected to agree. The data are provisional
#' and revised monthly; `fetched_at` records the vintage.
#'
#' Output: data/who-monthly.csv (gitignored: WHO terms are CC BY-NC-SA 3.0 IGO).
#'
#' Usage:
#'     Rscript R/data/03-fetch-who-monthly.R

suppressMessages({
    library(data.table)
    library(httr2)
    library(readxl)
})

URL <- paste0("https://immunizationdata.who.int/docs/librariesprovider21/",
              "measles-and-rubella/404-table-web-epi-curve-data.xlsx")
RAW <- here::here("data", "raw", "who", "404-table-web-epi-curve-data.xlsx")
OUT <- here::here("data", "who-monthly.csv")

dir.create(dirname(RAW), recursive = TRUE, showWarnings = FALSE)
invisible(request(URL) |> req_retry(max_tries = 4) |> req_perform(path = RAW))

d <- as.data.table(read_excel(RAW, sheet = "WEB"))
# Headers carry embedded line breaks ("Measles \r\nsuspect").
setnames(d, tolower(gsub("[^A-Za-z0-9]+", "_", trimws(names(d)))))
d <- d[iso3 == "BGD"]
counts <- setdiff(names(d), c("region", "country", "iso3", "year", "month"))
d[, (counts) := lapply(.SD, as.numeric), .SDcols = counts]
d[, `:=`(year = as.integer(year), month = as.integer(month),
         fetched_at = format(Sys.time(), "%Y-%m-%dT%H%M"))]
d[, c("region", "country") := NULL]
setorder(d, year, month)

fwrite(d, OUT)
message("wrote ", OUT, ": ", nrow(d), " months, ",
        min(d$year), " to ", max(d$year))
