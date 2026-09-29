#!/usr/bin/env Rscript
#'
#' Download published context documents on the 2026 Bangladesh measles
#' outbreak and write a manifest.
#'
#' These are second accounts of the outbreak, written from outside DGHS: WHO,
#' the UN Resident Coordinator's Office (RCO), UNICEF, and the health and
#' nutrition sectors in the Rohingya camps. Each source is fetched from its
#' publisher rather than a mirror. ReliefWeb is not used: its API needs an
#' approved appname and returns 403 without one.
#'
#'   who_don           Disease Outbreak News, from the JSON API behind who.int
#'                     (the prose is in fields; saved as JSON plus markdown).
#'   who_searo         SEARO fortnightly epidemiological bulletins. The index
#'                     page lists only the latest issue, but the PDFs are
#'                     numbered `2026_NN_searo_epi_bulletin.pdf`, so numbers
#'                     are probed upwards until three misses in a row.
#'   un_rco            RCO situation reports, found by the site's publication
#'                     search; each page links a `/en/download/` redirect.
#'   unicef            Humanitarian situation reports, from the appeals
#'                     listing (2026 items and any measles item).
#'   rohingya_health   Health Sector Cox's Bazar monthly bulletins and the
#'                     measles SOP, from the sector page.
#'   rohingya_ewars    Weekly EWARS bulletins in the sector's public Google
#'                     Drive folder, 2025 and 2026 only. The embedded folder
#'                     view lists titles and ids without an API key.
#'   rohingya_nutrition  Nutrition sector documents on acute malnutrition
#'                     (SMART surveys, quarterly bulletins, CMAM guideline,
#'                     IM updates), files uploaded in 2025 or 2026 only.
#'                     Meeting minutes are left out.
#'
#' Nothing is read by a model. Publication dates are taken from the document
#' title, slug or redirect filename when they carry one, otherwise from the
#' first date in the PDF's first page; `NA` where none is found. A document
#' that cannot be fetched is kept as a row with `path` NA and the reason in
#' `note`, so gaps are visible in the manifest.
#'
#' Usage:
#'     Rscript R/03-fetch-context.R [--refresh]
#'
#' `--refresh` re-downloads files already on disk.

suppressMessages({
    library(data.table)
    library(httr2)
})

UA <- "Mozilla/5.0 (measles-bgd; github.com/kathsherratt/measles-bgd)"
OUT_DIR <- here::here("data", "pdf", "context")
MANIFEST <- here::here("data", "manifest-context.csv")
REFRESH <- "--refresh" %in% commandArgs(trailingOnly = TRUE)

DON_API <- "https://www.who.int/api/news/diseaseoutbreaknews"
SEARO_INDEX <- paste0("https://www.who.int/southeastasia/outbreaks-and-emergencies/",
                      "health-emergency-information-risk-assessment/sear-epi-bulletins")
SEARO_PDF <- "https://cdn.who.int/media/docs/default-source/searo/whe/wherepib/%s_%02d_searo_epi_bulletin.pdf"
UN_BASE <- "https://bangladesh.un.org"
UNICEF_BASE <- "https://www.unicef.org"
RR_HEALTH <- "https://rohingyaresponse.org/sectors/coxs-bazar/health/"
RR_NUTRITION <- "https://rohingyaresponse.org/sectors/coxs-bazar/nutrition/"
DRIVE_FOLDER <- "1TXXVczxymWd_O9vl1XL5DmfJs_znXyEg"

MONTHS <- c("January", "February", "March", "April", "May", "June", "July",
            "August", "September", "October", "November", "December")

# ----------------------------------------------------------------- http ----

req_base <- function(url) {
    request(url) |>
        req_user_agent(UA) |>
        req_timeout(120) |>
        req_retry(max_tries = 4, backoff = function(i) 2^i) |>
        req_throttle(capacity = 30, fill_time_s = 60)
}

get_html <- function(url) resp_body_string(req_perform(req_base(url)))

#' Download to a `.part` file, check it is what the extension says, rename.
#'
#' An interrupted run can leave an empty file behind, so empty counts as
#' missing. A PDF must start with `%PDF`: Google Drive and some CDNs answer
#' 200 with an HTML page. Returns the final URL after redirects, or NA on
#' failure (the reason is attached as attribute `why`).
download <- function(url, path) {
    if (!REFRESH && file.exists(path) && file.size(path) > 0) {
        return(structure(url, cached = TRUE))
    }
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    tmp <- paste0(path, ".part")
    res <- tryCatch({
        resp <- req_perform(req_base(url), path = tmp)
        stopifnot(file.size(tmp) > 0)
        if (grepl("\\.pdf$", path)) {
            head <- readBin(tmp, "raw", 5)
            if (!identical(rawToChar(head), "%PDF-")) stop("response is not a PDF")
        }
        file.rename(tmp, path)
        resp_url(resp)
    }, error = function(e) {
        message("  ! ", url, ": ", conditionMessage(e))
        unlink(tmp)
        structure(NA_character_, why = conditionMessage(e))
    })
    res
}

safe_id <- function(x) {
    x <- utils::URLdecode(sub("\\.pdf(\\.pdf)?$", "", basename(x), ignore.case = TRUE))
    gsub("^-|-$", "", gsub("[^A-Za-z0-9._-]+", "-", x))
}

#' First "d Month yyyy" in a string, as a Date (NA if none).
find_date <- function(x) {
    m <- regmatches(x, regexpr(
        paste0("[0-9]{1,2}[ _%0-9A-Za-z-]{0,6}?(", paste(substr(MONTHS, 1, 3), collapse = "|"),
               ")[a-z]*[ _-]*(20)?[0-9]{2}\\b"), x, ignore.case = TRUE))
    if (!length(m)) return(as.Date(NA))
    day <- as.integer(sub("^([0-9]{1,2}).*", "\\1", m))
    mon <- match(tolower(substr(regmatches(m, regexpr("[A-Za-z]{3,}", m)), 1, 3)),
                 tolower(substr(MONTHS, 1, 3)))
    yr <- as.integer(sub(".*?([0-9]{2,4})$", "\\1", m, perl = TRUE))
    if (yr < 100) yr <- yr + 2000L
    as.Date(sprintf("%04d-%02d-%02d", yr, mon, day))
}

rows <- list()
add_row <- function(source, doc_id, title, published_date, url, path,
                    note = NA_character_) {
    rows[[length(rows) + 1]] <<- data.table(
        source = source, doc_id = doc_id, title = title,
        published_date = as.Date(published_date), url = url,
        path = path, note = note)
}

#' Fetch one document and add its row; failures become rows with path NA.
fetch_doc <- function(source, doc_id, title, published_date, url, ext = "pdf") {
    path <- file.path(OUT_DIR, source, paste0(doc_id, ".", ext))
    got <- download(url, path)
    if (is.na(got)) {
        add_row(source, doc_id, title, published_date, url, NA_character_,
                note = paste("download failed:", attr(got, "why")))
        return(invisible(NULL))
    }
    add_row(source, doc_id, title, published_date, url, path)
    invisible(got)
}

# ----------------------------------------------------------- WHO DON ----

#' Every Disease Outbreak News whose title mentions measles and Bangladesh.
#' DON598 is the known item; the search keeps it from being the only one.
fetch_don <- function() {
    q <- function(...) req_base(DON_API) |>
        req_url_query(sf_provider = "dynamicProvider372", sf_culture = "en", ...) |>
        req_perform() |> resp_body_json()
    idx <- q(`$orderby` = "PublicationDateAndTime desc", `$top` = 100,
             `$select` = "Title,PublicationDateAndTime,UrlName")$value
    idx <- rbindlist(lapply(idx, function(x) data.table(
        id = x$UrlName, title = x$Title,
        published = as.Date(substr(x$PublicationDateAndTime, 1, 10)))))
    idx <- idx[grepl("measles", title, ignore.case = TRUE) &
               grepl("bangladesh", title, ignore.case = TRUE)]
    idx <- unique(rbind(idx, data.table(id = "2026-DON598", title = NA_character_,
                                        published = as.Date(NA))), by = "id")
    for (i in seq_len(nrow(idx))) {
        id <- idx$id[i]
        json <- file.path(OUT_DIR, "who_don", paste0(id, ".json"))
        md <- sub("\\.json$", ".md", json)
        url <- paste0("https://www.who.int/emergencies/disease-outbreak-news/item/", id)
        if (REFRESH || !file.exists(json) || file.size(json) == 0) {
            rec <- tryCatch(q(`$filter` = sprintf("UrlName eq '%s'", id))$value,
                            error = function(e) list())
            if (!length(rec)) {
                add_row("who_don", id, idx$title[i], idx$published[i], url,
                        NA_character_, note = "not returned by API")
                next
            }
            dir.create(dirname(json), recursive = TRUE, showWarnings = FALSE)
            jsonlite::write_json(rec[[1]], paste0(json, ".part"),
                                 auto_unbox = TRUE, pretty = TRUE)
            file.rename(paste0(json, ".part"), json)
        }
        rec <- jsonlite::fromJSON(json, simplifyVector = FALSE)
        secs <- c("Summary", "Overview", "Epidemiology", "Assessment",
                  "Response", "Advice", "FurtherInformation")
        body <- vapply(secs, function(s) html_to_text(rec[[s]]), character(1))
        writeLines(c(paste0("# ", rec$Title), "",
                     paste(paste0("## ", secs[nzchar(body)], "\n\n", body[nzchar(body)]),
                           collapse = "\n\n")), md)
        add_row("who_don", id, rec$Title,
                substr(rec$PublicationDateAndTime, 1, 10), url, md)
    }
}

#' WHO writes DON sections as HTML; strip to plain text.
html_to_text <- function(x) {
    if (is.null(x) || !length(x) || !nzchar(x)) return("")
    x <- gsub("\r|​|﻿", "", x, perl = TRUE)
    x <- gsub("<(br|/p|/h[1-6]|/li|/tr)[^>]*>", "\n", x, perl = TRUE)
    x <- gsub("<[^>]*>", "", x, perl = TRUE)
    x <- gsub("&nbsp;| ", " ", x)
    x <- gsub("&amp;", "&", x, fixed = TRUE)
    x <- gsub("&lt;", "<", x, fixed = TRUE)
    x <- gsub("&gt;", ">", x, fixed = TRUE)
    x <- gsub("&quot;", "\"", x, fixed = TRUE)
    x <- gsub("&#39;|&rsquo;", "'", x)
    x <- gsub("[ \t]+", " ", x)
    x <- gsub(" *\n *", "\n", x)
    trimws(gsub("\n{3,}", "\n\n", x))
}

# -------------------------------------------------------- WHO SEARO ----

fetch_searo <- function(year = 2026L) {
    # The index page shows the latest issue's number; probing continues past
    # it until three consecutive misses.
    top <- tryCatch({
        h <- get_html(SEARO_INDEX)
        max(as.integer(sub(".*_([0-9]{2})_searo.*", "\\1",
            regmatches(h, gregexpr(sprintf("%d_[0-9]{2}_searo_epi_bulletin", year), h))[[1]])))
    }, error = function(e) 0L)
    message("SEARO index lists issue ", top)
    misses <- 0L
    n <- 0L
    while (misses < 3L) {
        n <- n + 1L
        url <- sprintf(SEARO_PDF, year, n)
        id <- sprintf("%d_%02d_searo_epi_bulletin", year, n)
        path <- file.path(OUT_DIR, "who_searo", paste0(id, ".pdf"))
        got <- suppressMessages(download(url, path))
        if (is.na(got)) {
            misses <- misses + 1L
            next
        }
        misses <- 0L
        txt <- tryCatch(pdftools::pdf_text(path), error = function(e) "")
        first <- txt[1]
        # Bulletin front page carries the edition date and reporting period.
        add_row("who_searo", id, sprintf("SEARO Epidemiological Bulletin %d, edition %d", year, n),
                find_date(first), url, path,
                note = if (any(grepl("measles", txt, ignore.case = TRUE)) &&
                           any(grepl("bangladesh", txt, ignore.case = TRUE))) {
                    "mentions measles and Bangladesh"
                } else "no measles/Bangladesh mention")
    }
}

# ------------------------------------------------------------ UN RCO ----

fetch_un <- function() {
    slugs <- character()
    for (page in 0:20) {
        h <- tryCatch(get_html(paste0(UN_BASE, "/en/resources/publications?search_api_fulltext=measles&page=", page)),
                      error = function(e) "")
        new <- setdiff(unique(regmatches(h, gregexpr('/en/[0-9]+-[^"]*measles[^"]*', h))[[1]]), slugs)
        if (!length(new)) break
        slugs <- c(slugs, new)
    }
    message(length(slugs), " UN RCO measles publications")
    for (s in slugs) {
        h <- get_html(paste0(UN_BASE, s))
        title <- sub(" \\| United Nations in Bangladesh$", "",
                     sub(".*<title>([^<]*)</title>.*", "\\1", gsub("\n", " ", h)))
        dl <- regmatches(h, regexpr("/en/download/[0-9]+/[0-9]+", h))
        id <- sub("^/en/([0-9]+)-.*", "\\1", s)
        if (!length(dl)) {
            add_row("un_rco", id, title, find_date(title), paste0(UN_BASE, s),
                    NA_character_, note = "no download link on page")
            next
        }
        got <- fetch_doc("un_rco", id, title, NA, paste0(UN_BASE, dl))
        # The redirect target's filename carries the date (e.g. 07May26); a
        # HEAD request resolves it whether or not the file was cached.
        target <- tryCatch(resp_url(req_perform(req_method(
            req_base(paste0(UN_BASE, dl)), "HEAD"))), error = function(e) "")
        d <- find_date(paste(title, utils::URLdecode(target)))
        if (!is.na(d)) rows[[length(rows)]]$published_date <<- d
        rows[[length(rows)]]$url <<- paste0(UN_BASE, s)
    }
}

# ------------------------------------------------------------- UNICEF ----

fetch_unicef <- function() {
    docs <- character()
    for (page in 0:10) {
        h <- tryCatch(get_html(paste0(UNICEF_BASE, "/appeals/bangladesh/situation-reports?page=", page)),
                      error = function(e) "")
        new <- setdiff(unique(regmatches(h, gregexpr('/documents/bangladesh[^"]*', h))[[1]]), docs)
        if (!length(new)) break
        docs <- c(docs, new)
    }
    docs <- docs[grepl("measles|2026", docs)]
    message(length(docs), " UNICEF situation reports for 2026 or measles")
    for (d in docs) {
        h <- get_html(paste0(UNICEF_BASE, d))
        title <- sub(" \\| UNICEF$", "", sub(".*<title>([^<]*)</title>.*", "\\1", gsub("\n", " ", h)))
        pdf <- regmatches(h, regexpr('/media/[0-9]+/file/[^"]*\\.pdf[^"]*', h))
        id <- sub("^/documents/", "", d)
        if (!length(pdf)) {
            add_row("unicef", id, title, find_date(title), paste0(UNICEF_BASE, d),
                    NA_character_, note = "no PDF link on page")
            next
        }
        fetch_doc("unicef", id, title, find_date(title),
                  paste0(UNICEF_BASE, utils::URLencode(pdf)))
    }
}

# ------------------------------------------------- Rohingya response ----

#' Links on a page as (href, text), in page order.
page_links <- function(url) {
    a <- xml2::xml_find_all(xml2::read_html(get_html(url)), "//a[@href]")
    data.table(href = xml2::xml_attr(a, "href"),
               text = trimws(gsub("\\s+", " ", xml2::xml_text(a))))
}

fetch_rr <- function() {
    hl <- unique(page_links(RR_HEALTH), by = "href")
    hl <- hl[grepl("uploads/2026/.*(monthly-Bulletin|Measles)", href, ignore.case = TRUE)]
    message(nrow(hl), " Health Sector bulletins / measles SOP")
    for (i in seq_len(nrow(hl))) {
        # Only the SOP's filename carries a date (ddmmyyyy).
        d <- if (grepl("[0-9]{8}\\.pdf$", hl$href[i])) {
            as.Date(sub(".*-([0-9]{8})\\.pdf$", "\\1", hl$href[i]), "%d%m%Y")
        } else NA
        fetch_doc("rohingya_health", safe_id(hl$href[i]), hl$text[i], d, hl$href[i])
    }

    nl <- unique(page_links(RR_NUTRITION), by = "href")
    nl <- nl[grepl("uploads/202[56]/.*\\.pdf$", href) &
             grepl("SMART|malnutrition|Quarterly Bulletin|CMAM|Nutrition Causal|IM update",
                   text, ignore.case = TRUE) &
             !grepl("Minutes|Working Group", text)]
    message(nrow(nl), " Nutrition Sector documents (uploaded 2025-26)")
    for (i in seq_len(nrow(nl))) {
        fetch_doc("rohingya_nutrition", safe_id(nl$href[i]), nl$text[i], NA, nl$href[i])
    }

    # Weekly EWARS bulletins. The embedded folder view lists titles, ids and
    # last-modified in one HTML page.
    h <- get_html(paste0("https://drive.google.com/embeddedfolderview?id=", DRIVE_FOLDER))
    m <- regmatches(h, gregexpr('id="entry-[^"]+".*?flip-entry-last-modified"><div>[^<]*</div>', h))[[1]]
    ew <- data.table(
        id = sub('^id="entry-([^"]+)".*', "\\1", m),
        title = trimws(gsub("&amp;", "&", sub('.*flip-entry-title">([^<]*)<.*', "\\1", m))),
        modified = sub('.*<div>([^<]*)</div>$', "\\1", m))
    message(nrow(ew), " files in the EWARS folder; ",
            sum(grepl("202[56]", ew$title)), " for 2025-26")
    ew <- ew[grepl("202[56]", title)]
    for (i in seq_len(nrow(ew))) {
        wk <- sub(".*- (W[0-9]+ 20[0-9]{2})\\.pdf$", "\\1", ew$title[i])
        got <- fetch_doc("rohingya_ewars", gsub(" ", "-", wk), ew$title[i], NA,
                         paste0("https://drive.google.com/uc?export=download&id=", ew$id[i]))
        rows[[length(rows)]]$note <<- paste0("drive modified ", ew$modified[i])
    }
}

# ------------------------------------------------------------------ run ----

fetchers <- list(who_don = fetch_don, who_searo = fetch_searo, un_rco = fetch_un,
                 unicef = fetch_unicef, rohingya = fetch_rr)
for (nm in names(fetchers)) {
    tryCatch(fetchers[[nm]](), error = function(e) {
        message("! ", nm, " failed: ", conditionMessage(e))
        add_row(nm, NA_character_, NA_character_, NA, NA_character_,
                NA_character_, note = paste("source failed:", conditionMessage(e)))
    })
}
man <- rbindlist(rows)

# ------------------------------------------------------------- manifest ----

doc_meta <- function(path) {
    if (is.na(path)) return(list(pages = NA_integer_, text_chars = NA_integer_))
    if (grepl("\\.pdf$", path)) {
        txt <- tryCatch(pdftools::pdf_text(path), error = function(e) character())
        return(list(pages = length(txt), text_chars = sum(nchar(txt))))
    }
    list(pages = NA_integer_,
         text_chars = nchar(paste(readLines(path, warn = FALSE), collapse = "\n")))
}
man[, md5 := ifelse(is.na(path), NA_character_, tools::md5sum(path))]
man[, c("pages", "text_chars") := rbindlist(lapply(path, doc_meta))]
man[, fetched_at := format(file.mtime(path), "%Y-%m-%dT%H:%M:%S")]
man[, path := sub(paste0("^", here::here(), "/"), "", path)]
setcolorder(man, c("source", "doc_id", "title", "published_date", "url", "path",
                   "md5", "pages", "text_chars", "fetched_at", "note"))

fwrite(man, MANIFEST)
message("wrote ", MANIFEST, ": ", nrow(man), " rows")
print(man[, .(docs = .N, fetched = sum(!is.na(path)),
              first = suppressWarnings(min(published_date, na.rm = TRUE)),
              last = suppressWarnings(max(published_date, na.rm = TRUE)),
              no_text = sum(grepl("pdf$", path) & text_chars == 0, na.rm = TRUE)),
          keyby = source])
