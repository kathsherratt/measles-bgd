#!/usr/bin/env Rscript
#'
#' Download every DGHS daily measles press release (হাম প্রেস রিলিজ).
#'
#' DGHS posts one press release per day on
#' https://dghs.gov.bd/pages/press-releases, mixed with dengue and other
#' releases. The listing is server-rendered, ten entries per `?page=`, newest
#' first. Each release page carries its attachments as `data-index="files-N"`
#' chips linking to Oracle object storage. The attachment is a PDF with a text
#' layer: numbers are ASCII and read cleanly, Bengali labels come out garbled
#' by a legacy font encoding.
#'
#' The date in the slug (ddmmyyyy in Bengali digits) is a filing label only.
#' The reporting window a release covers is read from the document in
#' sitrep/R/02-extract.R. Some dates are posted twice; both are kept.
#'
#' Usage:
#'     Rscript sitrep/R/01-fetch.R [--refresh]
#'
#' `--refresh` re-downloads files already on disk.

suppressMessages({
    library(data.table)
    library(httr2)
})

BASE <- "https://dghs.gov.bd"
LISTING <- paste0(BASE, "/pages/press-releases")
MAX_PAGES <- 60L
MEASLES_PREFIX <- "হাম-প্রেস-রিলিজ"

OUT_DIR <- here::here("sitrep", "data", "pdf", "dghs")
MANIFEST <- here::here("sitrep", "data", "manifest-dghs.csv")
REFRESH <- "--refresh" %in% commandArgs(trailingOnly = TRUE)

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ----------------------------------------------------------------- http ----

get_html <- function(url) {
    request(url) |>
        req_user_agent("measles-bgd (github.com/kathsherratt/measles-bgd)") |>
        req_retry(max_tries = 4, backoff = function(i) 2^i) |>
        req_throttle(capacity = 30, fill_time_s = 60) |>
        req_perform() |>
        resp_body_string()
}

bn_digits <- function(x) chartr("০১২৩৪৫৬৭৮৯", "0123456789", x)

# ---------------------------------------------------------------- index ----

#' Walk the listing until a page adds nothing new.
#'
#' The count shown on the page ("মোট ১৮০ এন্ট্রি") is not trusted as the stop
#' condition; a page that repeats the previous one is.
fetch_index <- function() {
    seen <- character()
    for (page in seq_len(MAX_PAGES)) {
        html <- get_html(paste0(LISTING, "?page=", page))
        hrefs <- unique(regmatches(
            html, gregexpr('/pages/press-releases/[^"]+', html)
        )[[1]])
        new <- setdiff(hrefs, seen)
        message("listing page ", page, ": ", length(new), " new")
        if (!length(new)) break
        seen <- c(seen, new)
    }
    slug <- utils::URLdecode(sub("^/pages/press-releases/", "", seen))
    idx <- data.table(href = seen, slug = slug)
    idx <- idx[startsWith(slug, MEASLES_PREFIX)]
    # Digits are converted before matching: a Bengali-digit character class
    # does not match reliably across R's regex engines and locales.
    # Early September slugs drop the day's leading zero (১০৯২০২৬ = 1/09/2026).
    idx[, label_date := as.IDate(
        formatC(as.integer(sub("^[^0-9]*([0-9]{7,8})-.*$", "\\1",
                               bn_digits(slug))), width = 8, flag = "0"),
        format = "%d%m%Y"
    )]
    idx[, release_id := sub(".*-", "", slug)]
    idx[order(label_date, release_id)]
}

#' Attachment URLs on one release page, in their displayed order.
attachments <- function(href) {
    html <- get_html(paste0(BASE, href))
    m <- regmatches(html, gregexpr(
        'data-index="files-[0-9]+"[^>]*>[^<]*<a[^>]*href="([^"]+)"', html
    ))[[1]]
    unique(sub('.*href="([^"]+)"$', "\\1", m))
}

# ------------------------------------------------------------- download ----

idx <- fetch_index()
message(nrow(idx), " measles releases, ",
        format(min(idx$label_date, na.rm = TRUE)), " to ",
        format(max(idx$label_date, na.rm = TRUE)),
        ", ", sum(is.na(idx$label_date)), " undated")

rows <- list()
for (i in seq_len(nrow(idx))) {
    r <- idx[i]
    urls <- tryCatch(attachments(r$href), error = function(e) {
        message("  ! ", r$slug, ": ", conditionMessage(e))
        character()
    })
    if (!length(urls)) {
        rows[[length(rows) + 1]] <- r[, .(label_date, release_id, href,
            file_n = NA_integer_, file_url = NA_character_,
            path = NA_character_)]
        next
    }
    for (k in seq_along(urls)) {
        ext <- tolower(tools::file_ext(urls[k]))
        path <- file.path(OUT_DIR, sprintf(
            "%s_%s_%d.%s", format(r$label_date, "%Y-%m-%d"), r$release_id, k, ext
        ))
        # An interrupted run can leave an empty file behind, so empty counts
        # as missing, and each download lands in a temp file first.
        if (REFRESH || !file.exists(path) || file.size(path) == 0) {
            ok <- tryCatch({
                tmp <- paste0(path, ".part")
                request(urls[k]) |> req_retry(max_tries = 4) |>
                    req_perform(path = tmp)
                stopifnot(file.size(tmp) > 0)
                file.rename(tmp, path)
            }, error = function(e) {
                message("  ! download ", urls[k], ": ", conditionMessage(e))
                FALSE
            })
            if (!ok) path <- NA_character_
        }
        rows[[length(rows) + 1]] <- r[, .(label_date, release_id, href,
            file_n = k, file_url = urls[k], path = path)]
    }
}
man <- rbindlist(rows)

# ------------------------------------------------------------- manifest ----

pdf_meta <- function(path) {
    if (is.na(path) || !grepl("\\.pdf$", path)) {
        return(list(pages = NA_integer_, text_chars = NA_integer_))
    }
    txt <- tryCatch(pdftools::pdf_text(path), error = function(e) character())
    list(pages = length(txt), text_chars = sum(nchar(txt)))
}
man[, md5 := ifelse(is.na(path), NA_character_, tools::md5sum(path))]
man[, c("pages", "text_chars") := rbindlist(lapply(path, pdf_meta))]
man[, path := sub(paste0("^", here::here(), "/"), "", path)]
man[, href := paste0(BASE, href)]

fwrite(man, MANIFEST)
message("wrote ", MANIFEST, ": ", nrow(man), " files from ",
        uniqueN(man$release_id), " releases")
