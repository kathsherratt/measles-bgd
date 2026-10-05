#!/usr/bin/env Rscript
#'
#' Fit Rt for one division from DGHS daily admissions (first-steps step 4).
#'
#' A renewal model on latent infections (epinowcast), with:
#'   - the generation interval: prior gi_central (gamma), discretised daily
#'     with the infection day censored and day 0 dropped;
#'   - a latent delay from infection to report: incubation (lognormal, to first
#'     symptoms) + fever onset to admission (lognormal) + admission to report
#'     (0 or 1 day), discretised once by simulation, with infection uniform
#'     within its day;
#'   - a weekly random walk on log Rt;
#'   - a day-of-week effect on observations (report day);
#'   - negative binomial observations.
#' All four distributions are read from data/parameters/priors.csv.
#'
#' Published platform days are final, so there is no reporting triangle: each
#' day is one report on its own date (max_delay = 1), and the delay to report
#' sits entirely in the latent delay. Rt over roughly the last 17 days (the
#' median infection-to-report delay) is informed mostly by the random walk.
#'
#' The series starts on 8 April: 7 April holds the backfill of 15 March to
#' 7 April (flag `prelaunch_backfill`), and earlier days are empty.
#'
#' Outputs:
#'   outputs/fits/rt_<division>_<measure>_<cutoff>.rds  fitted object (cache;
#'                                                     reused on rerun)
#'   outputs/rt/rt_<division>_<measure>_<cutoff>.csv    Rt quantiles by date
#'   outputs/rt/pmf_<cutoff>.csv                        delay PMFs used
#' Both directories are gitignored: the fit embeds DGHS counts.
#'
#' Usage (detached; minutes per division):
#'     nohup caffeinate -is Rscript R/analysis/01-fit-rt.R --division Dhaka \
#'       > outputs/logs/fit-rt_$(date +%F-%H%M).log 2>&1 &
#' Options: --division (default Dhaka), --measure (admitted | suspected,
#' default admitted), --cutoff (YYYY-MM-DD, default the last date held).

suppressMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(epinowcast)
})

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  i <- match(paste0("--", name), args)
  if (is.na(i)) default else args[i + 1]
}
DIVISION <- opt("division", "Dhaka")
MEASURE <- opt("measure", "admitted")
CASES <- here::here("data", "dghs-cases.csv")
PRIORS <- here::here("data", "parameters", "priors.csv")
START <- as.Date("2026-04-08")
SEED <- 20261005
N_SIM <- 1e6
GI_MAX <- 25     # days; the central gamma puts < 1e-6 beyond
DELAY_MAX <- 40  # days; infection to report beyond this is renormalised away

cases <- read_csv(CASES, show_col_types = FALSE)
CUTOFF <- as.Date(opt("cutoff", as.character(max(cases$date))))

# Data -----------------------------------------------------------------------

series <- cases |>
  filter(level == "division", division == DIVISION, measure == MEASURE,
         date >= START, date <= CUTOFF)
stopifnot(nrow(series) > 0, !anyDuplicated(series$date),
          all(is.na(series$flag) | series$flag == ""),
          nrow(series) == as.integer(CUTOFF - START) + 1)

obs <- series |>
  transmute(reference_date = date, report_date = date, confirm = value)
pobs <- enw_preprocess_data(obs, max_delay = 1)

# Delay PMFs from the priors -------------------------------------------------

priors <- read_csv(PRIORS, show_col_types = FALSE)
pick <- function(id, dist) {
  p <- priors |> filter(prior_id == id)
  stopifnot(nrow(p) == 1, p$distribution == dist)
  p
}
gi <- pick("gi_central", "gamma")
inc <- pick("incubation_central", "lognormal")
f2a <- pick("fever_admission_central", "lognormal")
a2r <- pick("admission_report_assumed", "discrete uniform")

# Generation interval: infector infected uniformly within its day
gi_pmf <- primarycensored::dpcens(0:GI_MAX, pgamma, shape = gi$par1, rate = gi$par2,
                                  D = GI_MAX + 1)
gi_pmf[1] <- 0
gi_pmf <- gi_pmf / sum(gi_pmf)

# Infection to report, discretised once: infection time within its day, plus
# incubation and fever-to-admission (continuous), floored to the admission
# day, plus the whole-day report delay
set.seed(SEED)
admit_day <- floor(runif(N_SIM) + rlnorm(N_SIM, inc$par1, inc$par2) +
                     rlnorm(N_SIM, f2a$par1, f2a$par2))
report_day <- admit_day + sample(a2r$par1:a2r$par2, N_SIM, replace = TRUE)
delay_pmf <- tabulate(pmin(report_day, DELAY_MAX + 1) + 1, nbins = DELAY_MAX + 2)
delay_pmf <- delay_pmf[seq_len(DELAY_MAX + 1)] / sum(delay_pmf[seq_len(DELAY_MAX + 1)])

dir.create(here::here("outputs", "rt"), showWarnings = FALSE, recursive = TRUE)
write_csv(tibble(day = 0:DELAY_MAX, generation_interval = c(gi_pmf, rep(0, DELAY_MAX - GI_MAX)),
                 infection_to_report = delay_pmf),
          here::here("outputs", "rt", paste0("pmf_", CUTOFF, ".csv")))
message(sprintf("GI mean %.2f; infection-to-report mean %.2f, beyond %d days %.4f",
                sum(0:GI_MAX * gi_pmf), sum(0:DELAY_MAX * delay_pmf), DELAY_MAX,
                mean(report_day > DELAY_MAX)))

# Fit (cached by division, measure and cutoff) -------------------------------

key <- paste(tolower(DIVISION), MEASURE, CUTOFF, sep = "_")
FIT <- here::here("outputs", "fits", paste0("rt_", key, ".rds"))
dir.create(dirname(FIT), showWarnings = FALSE, recursive = TRUE)

if (file.exists(FIT)) {
  message("Reusing cached fit ", FIT)
  fit <- readRDS(FIT)
} else {
  message("Fitting ", key, " (", nrow(obs), " days)")
  fit <- epinowcast(
    data = pobs,
    expectation = enw_expectation(
      r = ~ 1 + rw(week),
      generation_time = gi_pmf,
      latent_reporting_delay = delay_pmf,
      observation = ~ (1 | day_of_week),
      data = pobs
    ),
    reference = enw_reference(parametric = ~0, data = pobs),
    obs = enw_obs(family = "negbin", data = pobs),
    fit = enw_fit_opts(
      save_warmup = FALSE, pp = TRUE,
      chains = 4, parallel_chains = 4, threads_per_chain = 1,
      iter_warmup = 1000, iter_sampling = 1000,
      adapt_delta = 0.95, max_treedepth = 12,
      show_messages = FALSE, seed = SEED
    )
  )
  saveRDS(fit, FIT)
  message("Saved ", FIT)
}

# Diagnostics ------------------------------------------------------------------

message(sprintf("Run time %.1f min; divergent %d; max treedepth hits %d; max Rhat %.3f; min ESS bulk %.0f",
                fit$run_time / 60, fit$divergent_transitions, fit$no_at_max_treedepth,
                fit$max_rhat, min(fit$fit[[1]]$summary()$ess_bulk, na.rm = TRUE)))

# Rt by date ---------------------------------------------------------------------

# `r` is log Rt and carries no dates: the first gt_n days are seeded, and the
# latent series starts before the first observation by the delay length
# (as nc_rt() in bvd-analysis)
rt <- enw_posterior(fit$fit[[1]], variables = "r")
stan_data <- fit$data[[1]]
seed <- stan_data$expr_r_seed
n_latent <- nrow(rt) + seed
lead <- n_latent - stan_data$t
stopifnot(lead >= 0)
dates <- seq(START - lead, CUTOFF, by = "day")
stopifnot(length(dates) == n_latent)

out <- as_tibble(rt) |>
  transmute(date = dates[(seed + 1):n_latent],
            across(any_of(c("median", "q5", "q20", "q80", "q95")), exp),
            rhat) |>
  mutate(division = DIVISION, measure = MEASURE, cutoff = CUTOFF, .before = 1)
OUT <- here::here("outputs", "rt", paste0("rt_", key, ".csv"))
write_csv(out, OUT)
message("Wrote ", OUT)

print(out |> filter(weekdays(date) == "Monday") |>
        select(date, median, q5, q95), n = Inf)
