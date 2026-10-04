#!/usr/bin/env Rscript
#'
#' Fit delay distributions to binned delays in the parameter register.
#'
#' Domai 2022 (A33) reports days from fever onset and from rash onset to
#' admission in four bins (register rows P66-P73, quote-checked, bin edges
#' kept as checked text in `bin_text`). Each bin is fitted as an interval of
#' whole days with the onset day censored: onset is uniform within its day
#' (primarycensored, 1-day window) and the delay counted in whole days, so
#'   P(delay in [a, b] days) = F(b + 1) - F(a),  P(delay > 14) = 1 - F(15)
#' where F is the primary-censored CDF. The bin counts are multinomial;
#' lognormal and gamma are fitted by maximum likelihood (optim) and compared
#' by AIC. With four bins and two parameters there is one degree of freedom
#' left to check fit, and the shape inside the 0-3 day bin is weakly
#' identified.
#'
#' Infection to admission is then the incubation period (Lessler 2009,
#' lognormal, infection to first symptoms: P01, P65) plus the preferred
#' fever-to-admission fit, summarised by simulation.
#'
#' Output: data/parameters/delay-fits.csv
#'
#' Usage:
#'     Rscript R/parameters/04-fit-delays.R

suppressMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(primarycensored)
})

REGISTER <- here::here("data", "parameters", "measles_parameters.csv")
OUT <- here::here("data", "parameters", "delay-fits.csv")
SEED <- 20261005

register <- read_csv(REGISTER, col_types = cols(.default = col_character()),
                     show_col_types = FALSE)

# Binned rows: checked count, bin edges parsed from the checked bin text
# ("0-3d" is 0 to 3 days; ">14d" is 15 days or more)
bins <- function(ids) {
  rows <- register |> filter(id %in% ids)
  stopifnot(setequal(rows$id, ids), all(nzchar(rows$quote)), all(nzchar(rows$bin_text)))
  edges <- lapply(regmatches(rows$bin_text, gregexpr("\\d+", rows$bin_text)), as.numeric)
  rows |>
    transmute(id, bin_text, n = as.numeric(parameter_value),
              open = startsWith(bin_text, ">"),
              lower = vapply(edges, `[`, 0, 1) + open,
              upper = ifelse(open, Inf, vapply(edges, \(e) e[length(e)], 0)))
}

dists <- list(
  lognormal = list(p = plnorm, q = qlnorm, r = rlnorm, names = c("meanlog", "sdlog"),
                   start = function(m) c(log(m), 0.5),
                   moments = function(a, b) c(exp(a + b^2 / 2), sqrt((exp(b^2) - 1) * exp(2 * a + b^2)))),
  gamma = list(p = pgamma, q = qgamma, r = rgamma, names = c("shape", "rate"),
               start = function(m) c(2, 2 / m),
               moments = function(a, b) c(a / b, sqrt(a) / b))
)

# Primary-censored CDF at whole-day edges; edges at Inf give 1
pc_cdf <- function(q, d, par) {
  out <- rep(1, length(q))
  fin <- is.finite(q)
  args <- setNames(as.list(par), d$names)
  out[fin] <- do.call(pprimarycensored, c(list(q = q[fin], pdist = d$p, pwindow = 1), args))
  out
}

fit_bins <- function(b, dname) {
  d <- dists[[dname]]
  # Optimise on the log scale so both parameters stay positive (meanlog may
  # be negative in principle, but these delays have medians above 1 day)
  nll <- function(lp) {
    par <- exp(lp)
    pr <- pc_cdf(b$upper + 1, d, par) - pc_cdf(b$lower, d, par)
    if (any(!is.finite(pr)) || any(pr <= 0)) return(1e10)
    -sum(b$n * log(pr))
  }
  o <- optim(log(d$start(4)), nll, method = "Nelder-Mead",
             control = list(reltol = 1e-12, maxit = 5000))
  stopifnot(o$convergence == 0)
  par <- exp(o$par)
  pr <- pc_cdf(b$upper + 1, d, par) - pc_cdf(b$lower, d, par)
  m <- d$moments(par[1], par[2])
  tibble(dist = dname, par1_name = d$names[1], par1 = par[1],
         par2_name = d$names[2], par2 = par[2],
         mean = m[1], sd = m[2],
         median = d$q(0.5, par[1], par[2]), q95 = d$q(0.95, par[1], par[2]),
         loglik = -o$value, aic = 2 * o$value + 4,
         observed = paste(b$n, collapse = "; "),
         expected = paste(round(sum(b$n) * pr), collapse = "; "))
}

fit_source <- function(ids, quantity) {
  b <- bins(ids)
  bind_rows(lapply(names(dists), \(dn) fit_bins(b, dn))) |>
    mutate(quantity, register_rows = paste(ids, collapse = "; "),
           bins = paste(b$bin_text, collapse = "; "), n = sum(b$n),
           preferred = aic == min(aic), .before = 1)
}

fits <- bind_rows(
  fit_source(paste0("P", 66:69), "Fever onset to admission"),
  fit_source(paste0("P", 70:73), "Rash onset to admission")
)

# Infection to admission: incubation (lognormal, median and dispersion from
# the register) plus the preferred fever-to-admission fit
inc <- register |> filter(id %in% c("P01", "P65")) |>
  transmute(id, value = as.numeric(parameter_value))
stopifnot(nrow(inc) == 2)
inc_meanlog <- log(inc$value[inc$id == "P01"])
inc_sdlog <- log(inc$value[inc$id == "P65"])

f2a <- fits |> filter(quantity == "Fever onset to admission", preferred)
set.seed(SEED)
n_sim <- 1e6
total <- rlnorm(n_sim, inc_meanlog, inc_sdlog) +
  dists[[f2a$dist]]$r(n_sim, f2a$par1, f2a$par2)
conv <- tibble(quantity = "Infection to admission (incubation + fever onset to admission)",
               register_rows = paste("P01; P65;", f2a$register_rows),
               bins = NA_character_, n = NA_real_, preferred = TRUE,
               dist = paste("lognormal +", f2a$dist, "(simulated)"),
               mean = mean(total), sd = sd(total),
               median = median(total), q95 = unname(quantile(total, 0.95)))

out <- bind_rows(fits, conv) |>
  mutate(across(c(par1, par2, mean, sd, median, q95), \(x) round(x, 3)),
         across(c(loglik, aic), \(x) round(x, 1)))
write_csv(out, OUT, na = "")
print(select(out, quantity, dist, preferred, par1, par2, mean, sd, median, q95, aic, observed, expected),
      n = Inf, width = Inf)
