#!/usr/bin/env Rscript
#'
#' Build model priors from the parameter register.
#'
#' Every number in data/parameters/priors.csv is computed here from register
#' rows whose value was parsed from a checked quote
#' (`R/parameters/02-check-proposals.py`); none is typed. Each prior names
#' the rows it uses and how it was derived. All priors are drafts until a
#' person fills `reviewed_by`.
#'
#' Generation interval (renewal model, first-steps step 4):
#'   central      gamma; mean and SD are the averages of the two bigamma
#'                household fits in Klinkenberg & Nishiura 2011
#'                (Rhode Island 1917-23 and 1929-34)
#'   mean_low,    the shortest and longest serial interval means among
#'   mean_high    Vink 2014's six household datasets (serial and generation
#'                interval means coincide), with the central SD
#'   sd_low,      the outer ends of Klinkenberg's credible intervals for the
#'   sd_high      SD, with the central mean
#'   crosscheck   the quick fallback: Vink's pooled serial interval mean with
#'                the SD Marye 2026 assumed, used as a generation interval
#'
#' Output: data/parameters/priors.csv
#'
#' Usage:
#'     Rscript R/parameters/03-build-priors.R

suppressMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

REGISTER <- here::here("data", "parameters", "measles_parameters.csv")
OUT <- here::here("data", "parameters", "priors.csv")

register <- read_csv(REGISTER, col_types = cols(.default = col_character()),
                     show_col_types = FALSE)

# Values of checked rows only: a row without a quote was not parsed by script
row_values <- function(ids) {
  rows <- register |> filter(id %in% ids)
  stopifnot(setequal(rows$id, ids), all(!is.na(rows$quote) & nzchar(rows$quote)))
  rows |>
    transmute(id,
              value = as.numeric(parameter_value),
              lower = as.numeric(parameter_uncertainty_lower_value),
              upper = as.numeric(parameter_uncertainty_upper_value))
}

gi_mean <- row_values(c("P51", "P53"))
gi_sd <- row_values(c("P52", "P54"))
si_extremes <- row_values(c("P55", "P56"))
si_pooled <- row_values("P57")
si_sd_assumed <- row_values("P58")

central_mean <- round(mean(gi_mean$value), 1)
central_sd <- round(mean(gi_sd$value), 1)

prior <- function(role, mean, sd, rows, derivation) {
  tibble(prior_id = paste0("gi_", role),
         quantity = "Generation interval",
         used_in = "Rt renewal model (first-steps step 4)",
         role, distribution = "gamma", unit = "days",
         mean, sd,
         register_rows = paste(rows, collapse = "; "),
         derivation, status = "draft", reviewed_by = NA_character_)
}

priors <- bind_rows(
  prior("central", central_mean, central_sd, c("P51", "P52", "P53", "P54"),
        "Average of the two bigamma household fits (Klinkenberg & Nishiura 2011, Table 2): means and SDs averaged, rounded to 0.1 day"),
  prior("mean_low", min(si_extremes$value), central_sd, c("P55", "P52", "P54"),
        "Shortest serial interval mean of Vink 2014's six datasets (Kenya 1974-81), with the central SD"),
  prior("mean_high", max(si_extremes$value), central_sd, c("P56", "P52", "P54"),
        "Longest serial interval mean of Vink 2014's six datasets (US 1934), with the central SD"),
  prior("sd_low", central_mean, round(min(gi_sd$lower), 1), c("P51", "P53", "P52", "P54"),
        "Central mean with the lowest lower bound of Klinkenberg's 95% CrIs for the SD"),
  prior("sd_high", central_mean, round(max(gi_sd$upper), 1), c("P51", "P53", "P52", "P54"),
        "Central mean with the highest upper bound of Klinkenberg's 95% CrIs for the SD"),
  prior("crosscheck", si_pooled$value, si_sd_assumed$value, c("P57", "P58"),
        "Quick fallback: Vink 2014 pooled serial interval mean with the SD Marye 2026 assumed, used as a generation interval")
)

write_csv(priors, OUT, na = "")
print(select(priors, prior_id, mean, sd, register_rows), n = Inf)
