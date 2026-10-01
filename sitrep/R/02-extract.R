#!/usr/bin/env Rscript
#'
#' Extract daily counts from the DGHS measles press releases.
#'
#' The press releases are the secondary DGHS source. The platform dashboard
#' (`R/data/01-fetch-dashboard.R`) is primary: it holds the same counts, by
#' district, with corrections on the right days. The releases are kept for the
#' national series before the platform (15 March to 9 April, which the
#' dashboard loads onto 7 April), the footnotes explaining revisions, the
#' campaign tables, and as a cross-check (`sitrep/R/03-compare-dashboard.R`).
#'
#' Reads the PDFs listed in sitrep/data/manifest-dghs.csv with pdftools. Numbers
#' are
#' read from the text layer; no model is involved. Bengali labels come out
#' garbled by a legacy font encoding, in 37 spellings of 9 row names across the
#' corpus, so rows are matched on stable substrings (`division_of()`), not on
#' exact text.
#'
#' The division table has 12 columns, six measures for the last 24 hours and
#' then the same six cumulative since 15 March. Their order changed twice
#' (see `LAYOUTS`). The layout is not assigned by date: each candidate is tried
#' against the total row, and the one that satisfies every internal identity
#' (`layout_ok()`) is used. None or more than one fitting sends the release to
#' quarantine rather than to a guess.
#'
#' The date of record is the date printed in the release's footer. The slug
#' date is used only where the footer carries none, and the difference is
#' flagged.
#'
#' Checks written to sitrep/data/dghs-checks.csv:
#'   - divisions sum to the total row, per column;
#'   - page 1 national figures equal the total row;
#'   - cumulative(t) = cumulative(t-1) + 24h(t), national and by division,
#'     where the previous release is the previous day's.
#' A failed check is recorded, not corrected. The 18 May fall in cumulative
#' suspected cases is a revision by DGHS, and is data.
#'
#' Outputs (gitignored until publication terms are agreed):
#'   sitrep/data/dghs-daily.csv         long: report_date, geography, measure,
#'                                      period, value, file
#'   sitrep/data/dghs-campaign-raw.csv  MR campaign rows, numbers unlabelled
#'   sitrep/data/dghs-checks.csv        one row per check
#'   sitrep/data/dghs-notes.csv         footnotes and starred values, in
#'                                      Bengali, with empty translation columns
#'   sitrep/data/quarantine/dghs.csv    releases that could not be parsed
#'
#' Usage:
#'     Rscript sitrep/R/02-extract.R

suppressMessages({
    library(data.table)
})

MANIFEST <- here::here("sitrep", "data", "manifest-dghs.csv")
OUT_DAILY <- here::here("sitrep", "data", "dghs-daily.csv")
OUT_CAMPAIGN <- here::here("sitrep", "data", "dghs-campaign-raw.csv")
OUT_CHECKS <- here::here("sitrep", "data", "dghs-checks.csv")
OUT_NOTES <- here::here("sitrep", "data", "dghs-notes.csv")
OUT_QUARANTINE <- here::here("sitrep", "data", "quarantine", "dghs.csv")
CORRECTIONS <- here::here("sitrep", "assets", "corrections.csv")

MEASURES <- c("suspected", "admitted", "discharged", "suspected_deaths",
              "confirmed", "confirmed_deaths")

#' Column order of the division table, 24h block then cumulative block.
#' Identified by matching total rows against the next day's cumulatives.
LAYOUTS <- list(
    A = list(h24 = c("suspected", "admitted", "discharged",
                     "suspected_deaths", "confirmed", "confirmed_deaths"),
             cum = c("suspected", "admitted", "discharged",
                     "suspected_deaths", "confirmed", "confirmed_deaths")),
    # B's 24h death columns sit the other way round from A's: on 6, 8 and
    # 9 May the fourth column matches the change in cumulative confirmed
    # deaths and the sixth the change in suspected deaths.
    B = list(h24 = c("suspected", "admitted", "discharged",
                     "confirmed_deaths", "confirmed", "suspected_deaths"),
             cum = c("suspected", "admitted", "discharged",
                     "confirmed", "confirmed_deaths", "suspected_deaths")),
    C = list(h24 = c("suspected", "suspected_deaths", "confirmed",
                     "confirmed_deaths", "admitted", "discharged"),
             cum = c("suspected", "suspected_deaths", "confirmed",
                     "confirmed_deaths", "admitted", "discharged"))
)

# -------------------------------------------------------------- helpers ----

bn_digits <- function(x) chartr("০১২৩৪৫৬৭৮৯", "0123456789", x)

#' Division from a garbled row label. Order matters: রাজশাহী also ends in শা.
division_of <- function(label) {
    fcase(
        grepl("মাট$", label), "Total",
        grepl("ঢাকা", label), "Dhaka",
        grepl("ট্টগ্রাম", label), "Chattogram",
        grepl("াজশাহী", label), "Rajshahi",
        grepl("ং?পুর$", label), "Rangpur",
        grepl("^খু", label), "Khulna",
        # য় is sometimes precomposed (U+09DF), sometimes য + nukta.
        grepl("^ম(\u09DF|\u09AF\u09BC)মন", label), "Mymensingh",
        grepl("(লেট|লট|দেট)$", label), "Sylhet",
        grepl("শা[লে]$", label), "Barishal",
        default = NA_character_
    )
}

#' Numeric tokens on a line. A lone "-" is a printed zero.
tokens <- function(line) {
    tok <- regmatches(line, gregexpr("(?<=^|\\s)(-|[0-9][0-9,]*)(?=\\s|$)",
                                     line, perl = TRUE))[[1]]
    tok[tok == "-"] <- "0"
    as.numeric(gsub(",", "", tok))
}

#' TRUE when a total row read under a layout obeys every identity that holds
#' for real data, whatever the day.
layout_ok <- function(v, lay) {
    h <- setNames(v[1:6], lay$h24)
    k <- setNames(v[7:12], lay$cum)
    all(h <= k[names(h)]) &&
        k["suspected"] >= k["confirmed"] &&
        k["suspected"] >= k["admitted"] &&
        k["admitted"] >= k["discharged"] &&
        k["suspected_deaths"] >= k["confirmed_deaths"] &&
        k["confirmed"] >= k["confirmed_deaths"] &&
        # Plausibility, not identity: without it, layouts A and C both fit
        # April's total rows. Read as C, April's admissions become deaths,
        # a CFR of 64%; the real one has stayed under 2%.
        k["suspected_deaths"] <= 0.1 * k["suspected"]
}

#' Release date from the footer: the last dd-mm-yyyy on the last page that is
#' not the 15 March start date.
footer_date <- function(pages) {
    d <- regmatches(pages[length(pages)], gregexpr(
        "[0-9]{1,2}[-./][0-9]{1,2}[-./]20[0-9]{2}", pages[length(pages)]))[[1]]
    d <- d[!grepl("^15[-./]0?3[-./]", d)]
    if (!length(d)) return(as.IDate(NA))
    as.IDate(gsub("[./]", "-", d[length(d)]), format = "%d-%m-%Y")
}

#' Page 1 headline blocks, as a check on the total row and the only source
#' for the first two releases. Block 1: suspected 24h and cumulative,
#' confirmed 24h and cumulative, cumulative admitted, cumulative discharged.
#' Block 2 ends with two (24h, cumulative) death pairs whose order swaps
#' between May and September; suspected deaths are the larger cumulative.
page1 <- function(p1) {
    x <- unlist(strsplit(p1, "\n"))
    six <- Filter(function(v) length(v) == 6, lapply(x, tokens))
    if (length(six) < 2) return(NULL)
    b1 <- six[[1]]
    b2 <- six[[2]][3:6]
    d <- if (b2[2] >= b2[4]) b2 else b2[c(3, 4, 1, 2)]
    data.table(
        measure = c("suspected", "suspected", "confirmed", "confirmed",
                    "admitted", "discharged", "suspected_deaths",
                    "suspected_deaths", "confirmed_deaths", "confirmed_deaths"),
        period = c("24h", "cumulative", "24h", "cumulative", "cumulative",
                   "cumulative", "24h", "cumulative", "24h", "cumulative"),
        value = c(b1, d)
    )
}

# ---------------------------------------------------------------- parse ----

parse_release <- function(path) {
    pages <- bn_digits(pdftools::pdf_text(path))
    lines <- unlist(strsplit(pages, "\n"))
    n_num <- vapply(lines, function(l) length(tokens(l)), integer(1))

    div_lines <- lines[n_num >= 12 & !grepl("%", lines)]
    labels <- trimws(sub("^\\s*([^0-9-]+?)\\s+[-0-9].*$", "\\1", div_lines))
    div <- data.table(label = labels, geography = division_of(labels),
                      v = lapply(div_lines, function(l) tail(tokens(l), 12)))
    div <- div[!is.na(geography)]

    camp_lines <- lines[grepl("%", lines) & n_num >= 2]
    camp_labels <- trimws(sub("^\\s*([^0-9-]+?)\\s+[-0-9].*$", "\\1",
                              camp_lines))
    campaign <- data.table(
        label = camp_labels,
        is_city = grepl("কর্প|কপ্ট|কব্মা|ক্ল্পা", camp_labels),
        values = vapply(camp_lines, function(l) {
            paste(regmatches(l, gregexpr("[0-9][0-9,.]*%?", l))[[1]],
                  collapse = " ")
        }, character(1))
    )

    # Footnotes marked with asterisks explain revisions and late reports.
    # They are kept verbatim, in Bengali, for a person to translate: a note
    # is the starred line plus any continuation up to the next blank line.
    # Starred numbers on table rows are kept too, as the note's anchor.
    notes <- list()
    for (p in seq_along(pages)) {
        pl <- unlist(strsplit(pages[p], "\n"))
        starred <- grep("\\*", pl)
        for (s in starred) {
            is_row <- length(tokens(gsub("\\*", "", pl[s]))) >= 4
            txt <- pl[s]
            if (!is_row) {
                k <- s + 1
                while (k <= length(pl) && nzchar(trimws(pl[k])) &&
                       !grepl("\\*", pl[k]) && length(tokens(pl[k])) < 4) {
                    txt <- paste(txt, trimws(pl[k]))
                    k <- k + 1
                }
            }
            notes[[length(notes) + 1]] <- data.table(page = p,
                kind = if (is_row) "starred_value" else "note",
                text = gsub("\\s+", " ", trimws(txt)))
        }
    }

    list(date = footer_date(pages), n_pages = length(pages),
         division = div, national = page1(pages[1]), campaign = campaign,
         notes = rbindlist(notes))
}

man <- fread(MANIFEST)
man <- man[!is.na(path) & pages > 0]

daily <- list(); camp <- list(); quarantine <- list(); checks <- list()
notes_out <- list()

for (i in seq_len(nrow(man))) {
    f <- man$path[i]
    r <- tryCatch(parse_release(here::here(f)), error = function(e) e)
    if (inherits(r, "error")) {
        quarantine[[f]] <- data.table(file = f, reason = conditionMessage(r))
        next
    }
    date <- r$date
    date_source <- "footer"
    if (is.na(date)) {
        date <- man$label_date[i]
        date_source <- "slug"
    }

    if (nrow(r$division)) {
        total <- r$division[geography == "Total"]
        if (nrow(total) != 1 || lengths(total$v) != 12) {
            quarantine[[f]] <- data.table(file = f,
                reason = "no single 12-value total row")
            next
        }
        fits <- names(Filter(function(l) layout_ok(total$v[[1]], l), LAYOUTS))
        if (length(fits) != 1) {
            quarantine[[f]] <- data.table(file = f, reason = paste0(
                "layouts fitting total row: ",
                if (length(fits)) paste(fits, collapse = ",") else "none"))
            next
        }
        lay <- LAYOUTS[[fits]]
        rows <- r$division[, {
            vals <- v[[1]]
            if (length(vals) != 12) {
                list(measure = NA_character_, period = NA_character_,
                     value = NA_real_)
            } else {
                list(measure = c(lay$h24, lay$cum),
                     period = rep(c("24h", "cumulative"), each = 6),
                     value = vals)
            }
        }, by = .(geography, label)]
        rows[, `:=`(layout = fits, source = "division_table")]
        daily[[f]] <- rows[, .(report_date = date, date_source, geography,
            measure, period, value, layout, source, file = f)]
        if (!is.null(r$national)) {
            chk <- merge(r$national,
                         rows[geography == "Total", .(measure, period, table = value)],
                         by = c("measure", "period"))
            checks[[paste0(f, "p1")]] <- chk[, .(report_date = date, file = f,
                check = "page1_equals_total", geography = "Total", measure,
                period, expected = table, observed = value,
                pass = table == value)]
        }
    } else if (!is.null(r$national)) {
        # First releases: national headline only.
        daily[[f]] <- r$national[, .(report_date = date, date_source,
            geography = "Total", measure, period, value, layout = "0",
            source = "page1", file = f)]
    } else {
        quarantine[[f]] <- data.table(file = f,
            reason = "neither a division table nor page 1 blocks found")
        next
    }

    if (nrow(r$notes)) {
        notes_out[[f]] <- r$notes[, .(report_date = date, file = f, page,
                                      kind, text, translation = NA_character_,
                                      reviewed_by = NA_character_)]
    }
    if (nrow(r$campaign)) {
        camp[[f]] <- r$campaign[, .(report_date = date, file = f, label,
                                    is_city, values)]
    }
}

daily <- rbindlist(daily)

# ---------------------------------------------------------------- dates ----

# Two releases carrying one date: where the other copy's day is free, a
# release whose cumulatives run past its twin's is the next day's.
dup <- daily[geography == "Total" & measure == "suspected" &
             period == "cumulative", .(report_date, file, value)]
setorder(dup, report_date, value)
dup[, n := .N, by = report_date]
moved <- dup[n > 1][duplicated(report_date)]
for (j in seq_len(nrow(moved))) {
    nxt <- moved$report_date[j] + 1L
    if (!nxt %in% dup$report_date) {
        daily[file == moved$file[j], `:=`(report_date = nxt,
                                          date_source = "reordered")]
    }
}
still <- daily[, uniqueN(file), by = report_date][V1 > 1]
if (nrow(still)) {
    warning("dates still carried by more than one release: ",
            paste(still$report_date, collapse = ", "))
}

# ---------------------------------------------------------- corrections ----

# Hand corrections, each with its reason and evidence, for a person to
# confirm. `geography` may be a division, "Total", "division" (all eight) or
# "*"; `measure` may be "*". Applied values are kept in `value_raw`.
corr <- fread(CORRECTIONS, colClasses = list(character = "value"))
daily[, `:=`(value_raw = value, correction = NA_character_)]
for (j in seq_len(nrow(corr))) {
    cj <- corr[j]
    hit <- daily$report_date == as.IDate(cj$report_date) &
        daily$period == cj$period &
        (cj$measure == "*" | daily$measure == cj$measure) &
        (cj$geography == "*" |
         (cj$geography == "division" & daily$geography != "Total") |
         daily$geography == cj$geography)
    if (!any(hit)) warning("correction ", j, " matches no rows")
    daily[hit, `:=`(
        value = if (cj$action == "replace") as.numeric(cj$value) else NA_real_,
        correction = cj$reason)]
}

# --------------------------------------------------------------- checks ----

div <- daily[geography != "Total" & source == "division_table",
             .(sum_div = sum(value), n_div = .N),
             by = .(report_date, file, measure, period)]
tot <- daily[geography == "Total" & source == "division_table",
             .(report_date, file, measure, period, total = value)]
sums <- merge(div, tot, by = c("report_date", "file", "measure", "period"))
checks[["sum"]] <- sums[, .(report_date, file, check = "divisions_sum_to_total",
    geography = "Total", measure, period, expected = total,
    observed = sum_div, pass = total == sum_div & n_div == 8)]

wide <- dcast(daily, report_date + geography + measure ~ period,
              value.var = "value", fun.aggregate = function(x) x[1])
setorder(wide, geography, measure, report_date)
wide[, `:=`(prev_cum = shift(cumulative), prev_date = shift(report_date)),
     by = .(geography, measure)]
cc <- wide[!is.na(prev_cum) & report_date - prev_date == 1 & !is.na(`24h`)]
checks[["cum"]] <- cc[, .(report_date, file = NA_character_,
    check = "cumulative_equals_previous_plus_24h", geography, measure,
    period = "cumulative", expected = prev_cum + `24h`,
    observed = cumulative, pass = prev_cum + `24h` == cumulative)]

checks <- rbindlist(checks, use.names = TRUE)

# --------------------------------------------------------------- output ----

dir.create(dirname(OUT_QUARANTINE), recursive = TRUE, showWarnings = FALSE)
setorder(daily, report_date, geography, measure, period)
fwrite(daily, OUT_DAILY)
fwrite(rbindlist(camp), OUT_CAMPAIGN)
fwrite(checks, OUT_CHECKS)
fwrite(rbindlist(notes_out), OUT_NOTES)
fwrite(rbindlist(quarantine), OUT_QUARANTINE)

message(sprintf(
    "%d releases, %s to %s; %d quarantined; layouts %s",
    uniqueN(daily$file), min(daily$report_date), max(daily$report_date),
    length(quarantine),
    paste(daily[, uniqueN(file), by = layout][, paste0(layout, "=", V1)],
          collapse = " ")))
print(checks[, .(n = .N, failed = sum(!pass, na.rm = TRUE),
                 not_checked = sum(is.na(pass))), by = check])
