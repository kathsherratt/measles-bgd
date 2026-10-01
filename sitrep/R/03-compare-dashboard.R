#!/usr/bin/env Rscript
#'
#' Compare the DGHS platform dashboard with the DGHS press releases.
#'
#' The dashboard (`R/data/01-fetch-dashboard.R`, the same data as its Excel
#' export) is the primary DGHS series. The press releases
#' (`sitrep/R/02-extract.R`) are kept as a cross-check. This script matches the two by date, division and
#' 24h measure, nationally and by division, and summarises where they differ. Expected result (30 September):
#' from June they are identical except 3 August in Khulna (+6), and earlier
#' differences are corrections DGHS moved back to the day they belonged to
#' (`docs/plan.md`). If a new run departs from that, look before changing
#' anything: it may be a change of practice at DGHS.
#'
#' The dashboard's latest vintage is used. National dashboard values are the
#' sum of the divisions. Serum samples are dashboard-only and dropped.
#'
#' Output (gitignored until publication terms are agreed):
#'   sitrep/data/dghs-source-compare.csv  date, geography, measure, release,
#'                                        dashboard, diff (dashboard - release)
#'
#' Usage:
#'     Rscript sitrep/R/03-compare-dashboard.R

suppressMessages(library(data.table))

OUT <- here::here("sitrep", "data", "dghs-source-compare.csv")

# Dashboard field names to press-release measure names.
MEASURES <- c(suspected24h = "suspected", confirmed24h = "confirmed",
              admitted24h = "admitted", discharged24h = "discharged",
              suspectedDeath24h = "suspected_deaths",
              confirmedDeath24h = "confirmed_deaths")

# Dashboard spelling to press-release spelling.
GEOGRAPHY <- c(Barisal = "Barishal")

# ----------------------------------------------------------------- read ----

dash <- fread(here::here("data", "dghs-dashboard.csv"))[level == "division"]
dash <- dash[fetched_at == max(fetched_at), by = .(date)]
dash <- dash[measure %in% names(MEASURES)]
dash[, measure := MEASURES[measure]]
dash[geography %in% names(GEOGRAPHY), geography := GEOGRAPHY[geography]]
dash <- rbind(
    dash[, .(date, geography, measure, value)],
    dash[, .(geography = "Total", value = sum(value)), by = .(date, measure)]
)

pr <- fread(here::here("sitrep", "data", "dghs-daily.csv"))[period == "24h" & !is.na(value),
    .(date = report_date, geography, measure, release = value)]

m <- merge(pr, dash[, .(date, geography, measure, dashboard = value)],
           by = c("date", "geography", "measure"))
m[, diff := dashboard - release]
setorder(m, date, geography, measure)
fwrite(m, OUT)
message("wrote ", OUT, ": ", nrow(m), " rows, ", uniqueN(m$date), " dates")

# -------------------------------------------------------------- summary ----

net_pct <- function(d, r) round(100 * (sum(d) / sum(r) - 1), 1)

cat("\n== National: share of days where dashboard =, >, < press release\n")
print(m[geography == "Total", .(days = .N, equal = mean(diff == 0),
    higher = mean(diff > 0), lower = mean(diff < 0),
    net_pct = net_pct(dashboard, release)), by = measure])

cat("\n== National suspected by month\n")
print(m[geography == "Total" & measure == "suspected", .(days = .N,
    equal = sum(diff == 0), release = sum(release), dashboard = sum(dashboard),
    net_pct = net_pct(dashboard, release)),
    by = .(month = format(date, "%Y-%m"))])

cat("\n== Suspected by division and month: net % difference\n")
print(dcast(m[measure == "suspected",
    .(net_pct = net_pct(dashboard, release)),
    by = .(geography, month = format(date, "%m"))],
    geography ~ month, value.var = "net_pct"))

cat("\n== National suspected-death differences\n")
print(m[geography == "Total" & measure == "suspected_deaths" & diff != 0,
        .(date, release, dashboard, diff)])

cat("\n== From June: differences in any measure or division\n")
june <- m[date >= as.IDate("2026-06-01") & geography != "Total"]
print(june[, .(rows = .N, nonzero = sum(diff != 0))])
print(june[diff != 0])
