#!/usr/bin/env Rscript
#'
#' Build model priors from the parameter register.
#'
#' Every number in data/parameters/priors.csv is computed here from register
#' rows whose value was parsed from a checked quote
#' (`R/parameters/02-check-proposals.py`), from fits to those rows
#' (`R/parameters/04-fit-delays.R`), or from a stated assumption
#' (data/parameters/assumptions.csv); none is typed. Each prior names its
#' sources and how it was derived. All priors are drafts until a person
#' fills `reviewed_by`.
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
#' Delay from infection to report (latent and reporting delays, step 4):
#'   incubation        lognormal, infection to first symptoms (Lessler 2009),
#'                     central and the ends of the 95% CI of the median
#'   fever_admission   lognormal fitted to Domai 2022's binned fever onset to
#'                     admission (central); del Moral-Trinidad 2026's onset to
#'                     seeking care, median and IQR as a lognormal (crosscheck)
#'   admission_report  assumption S01
#'
#' Output: data/parameters/priors.csv
#'
#' Usage:
#'     Rscript R/parameters/04-fit-delays.R   # first, for the delay fits
#'     Rscript R/parameters/03-build-priors.R

suppressMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

PARAMS <- here::here("data", "parameters")
REGISTER <- file.path(PARAMS, "measles_parameters.csv")
FITS <- file.path(PARAMS, "delay-fits.csv")
ASSUMPTIONS <- file.path(PARAMS, "assumptions.csv")
OUT <- file.path(PARAMS, "priors.csv")

register <- read_csv(REGISTER, col_types = cols(.default = col_character()),
                     show_col_types = FALSE)
fits <- read_csv(FITS, show_col_types = FALSE)
assumptions <- read_csv(ASSUMPTIONS, show_col_types = FALSE)

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

# Natural-scale mean and SD, and the native parameters, of each family
gamma_ms <- function(mean, sd) list(mean = mean, sd = sd,
  par1_name = "shape", par1 = (mean / sd)^2, par2_name = "rate", par2 = mean / sd^2)
lnorm_par <- function(meanlog, sdlog) list(
  mean = exp(meanlog + sdlog^2 / 2), sd = sqrt((exp(sdlog^2) - 1) * exp(2 * meanlog + sdlog^2)),
  par1_name = "meanlog", par1 = meanlog, par2_name = "sdlog", par2 = sdlog)
dunif_int <- function(lower, upper) {
  k <- lower:upper
  list(mean = mean(k), sd = sqrt(mean((k - mean(k))^2)),
       par1_name = "lower", par1 = lower, par2_name = "upper", par2 = upper)
}

prior <- function(prior_id, quantity, used_in, role, distribution, p, sources, derivation) {
  tibble(prior_id, quantity, used_in, role, distribution, unit = "days",
         mean = round(p$mean, 2), sd = round(p$sd, 2),
         par1_name = p$par1_name, par1 = round(p$par1, 3),
         par2_name = p$par2_name, par2 = round(p$par2, 3),
         register_rows = paste(sources, collapse = "; "),
         derivation, status = "draft", reviewed_by = NA_character_)
}

# Generation interval ----------------------------------------------------------

gi_mean <- row_values(c("P51", "P53"))
gi_sd <- row_values(c("P52", "P54"))
si_extremes <- row_values(c("P55", "P56"))
si_pooled <- row_values("P57")
si_sd_assumed <- row_values("P58")

central_mean <- round(mean(gi_mean$value), 1)
central_sd <- round(mean(gi_sd$value), 1)

gi <- function(role, mean, sd, rows, derivation) {
  prior(paste0("gi_", role), "Generation interval", "Rt renewal model (first-steps step 4)",
        role, "gamma", gamma_ms(mean, sd), rows, derivation)
}

gi_priors <- bind_rows(
  gi("central", central_mean, central_sd, c("P51", "P52", "P53", "P54"),
     "Average of the two bigamma household fits (Klinkenberg & Nishiura 2011, Table 2): means and SDs averaged, rounded to 0.1 day"),
  gi("mean_low", min(si_extremes$value), central_sd, c("P55", "P52", "P54"),
     "Shortest serial interval mean of Vink 2014's six datasets (Kenya 1974-81), with the central SD"),
  gi("mean_high", max(si_extremes$value), central_sd, c("P56", "P52", "P54"),
     "Longest serial interval mean of Vink 2014's six datasets (US 1934), with the central SD"),
  gi("sd_low", central_mean, round(min(gi_sd$lower), 1), c("P51", "P53", "P52", "P54"),
     "Central mean with the lowest lower bound of Klinkenberg's 95% CrIs for the SD"),
  gi("sd_high", central_mean, round(max(gi_sd$upper), 1), c("P51", "P53", "P52", "P54"),
     "Central mean with the highest upper bound of Klinkenberg's 95% CrIs for the SD"),
  gi("crosscheck", si_pooled$value, si_sd_assumed$value, c("P57", "P58"),
     "Quick fallback: Vink 2014 pooled serial interval mean with the SD Marye 2026 assumed, used as a generation interval")
)

# Infection to report ----------------------------------------------------------

inc_median <- row_values("P01")
inc_disp <- row_values("P65")
inc_sdlog <- log(inc_disp$value)

inc <- function(role, median, derivation) {
  prior(paste0("incubation_", role), "Incubation period (infection to first symptoms)",
        "Rt renewal model: latent delay to symptom onset (first-steps step 4)",
        role, "lognormal", lnorm_par(log(median), inc_sdlog), c("P01", "P65"), derivation)
}

f2a_fit <- fits |> filter(quantity == "Fever onset to admission", preferred)
stopifnot(nrow(f2a_fit) == 1, f2a_fit$dist == "lognormal")
care <- row_values("P77")

assumed <- assumptions |> filter(assumption_id == "S01")
stopifnot(nrow(assumed) == 1, assumed$distribution == "discrete uniform")

delay_priors <- bind_rows(
  inc("central", inc_median$value,
      "Lessler 2009 pooled lognormal: meanlog = log(median), sdlog = log(dispersion)"),
  inc("median_low", inc_median$lower,
      "Lower end of the 95% CI of Lessler's median, with the central dispersion"),
  inc("median_high", inc_median$upper,
      "Upper end of the 95% CI of Lessler's median, with the central dispersion"),
  prior("fever_admission_central", "Fever onset to admission",
        "Rt renewal model: reporting delay, symptom onset to admission (first-steps step 4)",
        "central", "lognormal", lnorm_par(f2a_fit$par1, f2a_fit$par2),
        strsplit(f2a_fit$register_rows, "; ")[[1]],
        "Lognormal fitted by maximum likelihood to Domai 2022's binned whole-day delays, onset day censored (R/parameters/04-fit-delays.R); preferred to gamma by AIC. Manila referral hospital, 2016-19"),
  prior("fever_admission_crosscheck", "Fever onset to admission",
        "Rt renewal model: reporting delay, symptom onset to admission (first-steps step 4)",
        "crosscheck", "lognormal",
        lnorm_par(log(care$value), (log(care$upper) - log(care$lower)) / (2 * qnorm(0.75))),
        "P77",
        "del Moral-Trinidad 2026 onset to seeking care among hospitalised: meanlog = log(median), sdlog from the IQR width on the log scale. Approximate: the IQR is not symmetric about the median on the log scale"),
  prior("admission_report_assumed", "Admission to DGHS report",
        "Rt renewal model: reporting delay, admission to report (first-steps step 4)",
        "assumption", "discrete uniform", dunif_int(assumed$lower, assumed$upper),
        "S01", assumed$rationale)
)

priors <- bind_rows(gi_priors, delay_priors)
write_csv(priors, OUT, na = "")
print(select(priors, prior_id, distribution, mean, sd, par1, par2, register_rows), n = Inf)
