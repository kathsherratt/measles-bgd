#!/usr/bin/env Rscript
#'
#' Download covariates for the 2026 Bangladesh measles outbreak analysis.
#'
#' Everything comes from the Humanitarian Data Exchange (HDX). Resource URLs
#' are resolved at run time from the CKAN `package_show` endpoint rather than
#' hard-coded, since HDX resource ids change when a publisher re-uploads.
#' Raw files go to data/raw/hdx/<dataset>/ (gitignored, refetchable from the
#' manifest); tidy outputs go to data/covariates/ (openly licensed, so
#' committable; the licence of each source is recorded in the manifest).
#'
#' Sources and choices:
#'   cod-ab-bgd       OCHA/BBS admin boundaries. Only the adm1 (division) and
#'                    adm2 (district) layers of the GeoJSON zip are kept, and
#'                    simplified to under 5 MB each. Simplification is for
#'                    mapping only; do not use it for area calculations.
#'   cod-ps-bgd       2022 census-based population projections, adm1 and adm2,
#'                    total plus sex-by-5-year age bands. Names in this file
#'                    (Barisal, Chittagong) differ from the boundary file
#'                    (Barishal, Chattogram); join on pcode.
#'   dhs-subnational-data-for-bangladesh
#'                    DHS Program subnational indicators, one CSV per topic.
#'                    Anthropometry, Immunization and Micronutrients are used.
#'                    The latest survey per indicator is kept, which differs by
#'                    topic: the HDX Immunization file stops at BDHS 2017-18
#'                    and its only measles indicator is "measles vaccination
#'                    received" (children 12-23 months, no MCV1/MCV2 split).
#'                    Only the eight current divisions are kept; the file also
#'                    holds pre-2015 aggregates (Chattogram/Sylhet, Dhaka
#'                    before 2015, Rajshahi/Rangpur), and repeats some rows.
#'   who-data-for-bgd WHO GHO "Immunization coverage and vaccine-preventable
#'                    diseases" CSV, from which the national WUENIC series for
#'                    MCV1 (WHS8_110) and MCV2 (MCV2) are extracted.
#'   outline-of-camps-sites-of-rohingya-refugees-in-cox-s-bazar-bangladesh
#'                    ISCG camp outlines (level A1, 33 camps), shapefile zip,
#'                    reprojected from UTM 46N to WGS84.
#'   unicef-nt-ant-whz-ne2 / -ne3
#'                    UNICEF/WHO/World Bank Joint Malnutrition Estimates
#'                    (wasting < -2 SD and severe wasting < -3 SD). The CSV
#'                    covers all countries; Bangladesh rows are kept.
#'   Camp population  HDX is searched for UNHCR/ISCG Rohingya population by
#'                    camp dated 2025 or 2026. Candidates are logged. Nothing
#'                    is written unless a camp-level resource is found: the
#'                    by-camp UNHCR/RRRC registration series on HDX stops in
#'                    2021.
#'
#' Usage:
#'     Rscript R/04-fetch-covariates.R [--refresh]
#'
#' `--refresh` re-downloads files already on disk.

suppressMessages({
    library(data.table)
    library(httr2)
    library(sf)
})

HDX <- "https://data.humdata.org/api/3/action"
RAW_DIR <- here::here("data", "raw", "hdx")
OUT_DIR <- here::here("data", "covariates")
MANIFEST <- here::here("data", "manifest-covariates.csv")
REFRESH <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
MAX_GEOJSON_MB <- 5

dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# The eight divisions, with the spellings that appear in DGHS releases, DHS,
# the census population file and the OCHA boundaries.
DIVISION_VARIANTS <- c(
    BD10 = "Barishal|Barisal",
    BD20 = "Chattogram|Chittagong",
    BD30 = "Dhaka",
    BD40 = "Khulna",
    BD45 = "Mymensingh",
    BD50 = "Rajshahi",
    BD55 = "Rangpur",
    BD60 = "Sylhet"
)

# ----------------------------------------------------------------- http ----

hdx_package <- function(id) {
    request(paste0(HDX, "/package_show")) |>
        req_url_query(id = id) |>
        req_user_agent("measles-bgd (github.com/kathsherratt/measles-bgd)") |>
        req_retry(max_tries = 4, backoff = function(i) 2^i) |>
        req_perform() |>
        resp_body_json(simplifyVector = TRUE) |>
        (\(x) x$result)()
}

hdx_search <- function(q, rows = 25) {
    request(paste0(HDX, "/package_search")) |>
        req_url_query(q = q, rows = rows) |>
        req_user_agent("measles-bgd (github.com/kathsherratt/measles-bgd)") |>
        req_retry(max_tries = 4, backoff = function(i) 2^i) |>
        req_perform() |>
        resp_body_json(simplifyVector = TRUE) |>
        (\(x) x$result$results)()
}

# ------------------------------------------------------------- download ----

manifest_rows <- list()

#' Download the first resource of `pkg` whose name matches `pattern` (fixed
#' string), record it in the manifest and return the local path.
fetch_resource <- function(pkg_id, pattern) {
    pkg <- hdx_package(pkg_id)
    res <- pkg$resources[grepl(pattern, pkg$resources$name, fixed = TRUE), ]
    if (!nrow(res)) stop("no resource matching '", pattern, "' in ", pkg_id)
    res <- res[1, ]
    dir <- file.path(RAW_DIR, pkg_id)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    ext <- tolower(tools::file_ext(sub("\\?.*$", "", res$url)))
    if (!nzchar(ext) || nchar(ext) > 5) ext <- "csv"
    path <- file.path(dir, paste0(
        gsub("[^A-Za-z0-9]+", "-", tools::file_path_sans_ext(res$name)), ".", ext
    ))
    if (grepl(paste0("\\.", ext, "$"), res$name, ignore.case = TRUE)) {
        path <- file.path(dir, res$name)
    }
    # An interrupted run can leave an empty file behind, so empty counts as
    # missing, and each download lands in a temp file first.
    if (REFRESH || !file.exists(path) || file.size(path) == 0) {
        message("downloading ", pkg_id, ": ", res$name)
        tmp <- paste0(path, ".part")
        request(res$url) |>
            req_user_agent("measles-bgd (github.com/kathsherratt/measles-bgd)") |>
            req_retry(max_tries = 4, backoff = function(i) 2^i) |>
            req_timeout(600) |>
            req_perform(path = tmp)
        stopifnot(file.size(tmp) > 0)
        file.rename(tmp, path)
    }
    manifest_rows[[length(manifest_rows) + 1]] <<- data.table(
        dataset = pkg_id,
        resource = res$name,
        licence = pkg$license_title,
        source_url = res$url,
        last_modified = res$last_modified,
        path = sub(paste0("^", here::here(), "/"), "", path),
        md5 = unname(tools::md5sum(path)),
        fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    )
    path
}

# ------------------------------------------------------------------ geo ----

#' Write `s` as GeoJSON, simplifying until the file is under MAX_GEOJSON_MB.
#'
#' Tolerances are in degrees (about 100 m per 0.001) with S2 off, since the
#' layers are in WGS84. Topology is preserved per polygon but shared borders
#' are simplified independently, so thin slivers can open between districts.
write_geojson <- function(s, path) {
    s <- st_transform(s, 4326)
    write_one <- function(x) {
        unlink(path)
        st_write(x, path, quiet = TRUE, delete_dsn = TRUE,
                 layer_options = "COORDINATE_PRECISION=5")
        file.size(path) / 1e6
    }
    mb <- write_one(s)
    old <- sf_use_s2(FALSE)
    on.exit(sf_use_s2(old))
    for (tol in c(0.0005, 0.001, 0.002, 0.004, 0.008)) {
        if (mb <= MAX_GEOJSON_MB) break
        mb <- write_one(suppressWarnings(
            st_simplify(s, preserveTopology = TRUE, dTolerance = tol)
        ))
        message("  simplified at ", tol, " degrees: ", round(mb, 2), " MB")
    }
    stopifnot(mb <= MAX_GEOJSON_MB)
    message("wrote ", path, ": ", nrow(s), " features, ", round(mb, 2), " MB")
}

# --------------------------------------------------- 1. admin boundaries ----

zip_path <- fetch_resource("cod-ab-bgd", "geojson.zip")
zip_dir <- file.path(dirname(zip_path), "geojson")
unzip(zip_path, exdir = zip_dir, overwrite = TRUE)

adm1 <- st_read(file.path(zip_dir, "bgd_admin1.geojson"), quiet = TRUE)
adm2 <- st_read(file.path(zip_dir, "bgd_admin2.geojson"), quiet = TRUE)

adm1 <- adm1[, c("adm1_pcode", "adm1_name", "area_sqkm")]
adm2 <- adm2[, c("adm2_pcode", "adm2_name", "adm1_pcode", "adm1_name",
                 "area_sqkm")]
write_geojson(adm1, file.path(OUT_DIR, "bgd_adm1.geojson"))
write_geojson(adm2, file.path(OUT_DIR, "bgd_adm2.geojson"))

lookup <- as.data.table(st_drop_geometry(adm2))[
    , .(adm1_pcode, adm1_name, adm2_pcode, adm2_name)
]
stopifnot(setequal(lookup$adm1_pcode, names(DIVISION_VARIANTS)))
lookup[, adm1_name_variants := DIVISION_VARIANTS[adm1_pcode]]
setorder(lookup, adm1_pcode, adm2_pcode)
fwrite(lookup, file.path(OUT_DIR, "admin_lookup.csv"))
message("wrote admin_lookup.csv: ", nrow(lookup), " districts")

# ------------------------------------------------------- 2. population ----

read_pop <- function(level) {
    path <- fetch_resource("cod-ps-bgd", sprintf("bgd_admpop_%s_2022.csv", level))
    d <- fread(path)
    setnames(d, tolower(names(d)))
    d[, c("iso3", "adm0_name", "adm0_pcode") := NULL]
    d
}
for (level in c("adm1", "adm2")) {
    d <- read_pop(level)
    out <- file.path(OUT_DIR, sprintf("population_%s.csv", level))
    fwrite(d, out)
    message("wrote ", out, ": ", nrow(d), " rows; national total ",
            format(sum(d$t_tl), big.mark = ","))
}

# ------------------------------------------------------------------ dhs ----

# Explicit indicator ids: the file has no MCV1/MCV2 split, so "measles" is
# CH_VACC_C_MSL. Fully vaccinated (BAS) is kept as a general routine
# immunisation marker.
DHS_TOPICS <- c("Anthropometry Data", "Immunization Data",
                "Micronutrients Data")
DHS_INDICATORS <- c(
    CN_NUTS_C_WH2 = "wasting",
    CN_NUTS_C_WH3 = "severe wasting",
    CN_NUTS_C_HA2 = "stunting",
    CN_NUTS_C_HA3 = "severe stunting",
    CN_NUTS_C_WA2 = "underweight",
    CN_NUTS_C_WA3 = "severe underweight",
    CH_VACC_C_MSL = "measles vaccination",
    CH_VACC_C_BAS = "fully vaccinated",
    CN_MIAC_C_VAS = "vitamin A supplementation"
)

dhs <- rbindlist(lapply(DHS_TOPICS, function(topic) {
    fread(fetch_resource("dhs-subnational-data-for-bangladesh", topic))
}), fill = TRUE)
dhs <- dhs[!startsWith(ISO3, "#")]  # HXL tag row, if present
dhs <- dhs[IndicatorId %in% names(DHS_INDICATORS) &
               Location %in% adm1$adm1_name]
dhs <- dhs[dhs[, .I[SurveyYear == max(SurveyYear)], by = IndicatorId]$V1]
dhs <- unique(dhs, by = c("SurveyId", "IndicatorId", "Location"))
dhs <- merge(dhs, as.data.table(st_drop_geometry(adm1))[
    , .(Location = adm1_name, adm1_pcode)
], by = "Location")
dhs_out <- dhs[, .(
    survey = SurveyId, survey_year = SurveyYear, division = Location,
    adm1_pcode, indicator_id = IndicatorId, indicator = Indicator,
    indicator_short = DHS_INDICATORS[IndicatorId], value = Value,
    denominator = DenominatorWeighted,
    denominator_unweighted = DenominatorUnweighted,
    ci_low = CILow, ci_high = CIHigh
)]
setorder(dhs_out, indicator_id, division)
fwrite(dhs_out, file.path(OUT_DIR, "dhs_division.csv"))
message("wrote dhs_division.csv: ", nrow(dhs_out), " rows")
print(unique(dhs_out[, .(survey, indicator_id, indicator)]))

# ---------------------------------------------------------------- wuenic ----

who <- fread(fetch_resource("who-data-for-bgd", "Immunization coverage"))
setnames(who, c("gho_code", "gho_display", "gho_url", "year", "start_year",
                "end_year", "region_code", "region", "country_code", "country",
                "dim_type", "dim_code", "dim_name", "numeric", "value", "low",
                "high"))
wuenic <- who[gho_code %in% c("WHS8_110", "MCV2")][, .(
    country_code, indicator_code = gho_code,
    vaccine = fifelse(gho_code == "MCV2", "MCV2", "MCV1"),
    indicator = gho_display, year, coverage_pct = numeric
)]
setorder(wuenic, vaccine, year)
fwrite(wuenic, file.path(OUT_DIR, "wuenic_national.csv"))
message("wrote wuenic_national.csv: ", nrow(wuenic), " rows, ",
        min(wuenic$year), "-", max(wuenic$year))

# ---------------------------------------------------------------- camps ----

camp_zip <- fetch_resource(
    "outline-of-camps-sites-of-rohingya-refugees-in-cox-s-bazar-bangladesh",
    "A1_Camp_Outlines.zip"
)
camp_dir <- file.path(dirname(camp_zip), "A1_Camp_Outlines")
unzip(camp_zip, exdir = camp_dir, overwrite = TRUE)
camps <- st_read(list.files(camp_dir, pattern = "\\.shp$", full.names = TRUE),
                 quiet = TRUE)
camps <- camps[, c("CampSSID", "CampName", "CampLabel", "NPMCamp", "Upazila",
                   "Union", "Settlement", "AreaSqKM")]
names(camps)[1:7] <- c("camp_id", "camp_name", "camp_label", "camp_name_npm",
                       "upazila", "union", "settlement")
names(camps)[names(camps) == "AreaSqKM"] <- "area_sqkm"
camps <- camps[order(camps$camp_id), ]
write_geojson(camps, file.path(OUT_DIR, "camps.geojson"))

# -------------------------------------------------------------- unicef ----

unicef_cols <- c(
    REF_AREA = "country_code", INDICATOR = "indicator_id", SEX = "sex",
    AGE = "age", WEALTH_QUINTILE = "wealth_quintile", RESIDENCE = "residence",
    MATERNAL_EDU_LVL = "maternal_education", TIME_PERIOD = "time_period",
    COVERAGE_TIME = "coverage_time", OBS_VALUE = "value_pct",
    LOWER_BOUND = "ci_low", UPPER_BOUND = "ci_high",
    WGTD_SAMPL_SIZE = "sample_size", DATA_SOURCE = "data_source"
)
unicef <- rbindlist(lapply(
    c("unicef-nt-ant-whz-ne2", "unicef-nt-ant-whz-ne3"),
    function(id) {
        d <- fread(fetch_resource(id, "(CSV)"))[REF_AREA == "BGD"]
        d[, names(unicef_cols), with = FALSE]
    }
))
setnames(unicef, names(unicef_cols), unname(unicef_cols))
unicef[, indicator := fifelse(indicator_id == "NT_ANT_WHZ_NE3",
                              "severe wasting (< -3 SD)",
                              "wasting (< -2 SD)")]
setorder(unicef, indicator_id, time_period, sex, age, wealth_quintile, residence)
fwrite(unicef, file.path(OUT_DIR, "unicef_wasting.csv"))
message("wrote unicef_wasting.csv: ", nrow(unicef), " rows")

# ------------------------------------------------------ camp population ----

# HDX has no consistent by-camp population dataset for 2025-2026, so search
# and log candidates: resources dated 2025 or 2026 in Rohingya/refugee
# datasets, by name or file name, that mention camps or population.
cand <- rbindlist(lapply(c(
    "rohingya population camp UNHCR", "Rohingya refugee population by camp",
    "Cox's Bazar refugee population registration"
), function(q) {
    pk <- hdx_search(q)
    if (!length(pk)) return(NULL)
    rbindlist(lapply(seq_len(nrow(pk)), function(i) {
        r <- pk$resources[[i]]
        if (is.null(r) || !nrow(r)) return(NULL)
        data.table(dataset = pk$name[i], title = pk$title[i],
                   resource = r$name, format = r$format,
                   last_modified = r$last_modified)
    }))
}), fill = TRUE)
cand <- unique(cand)[
    grepl("rohingya|bangladesh|bgd|cox", paste(dataset, title), ignore.case = TRUE) &
        grepl("202[56]", paste(resource, last_modified)) &
        grepl("camp|popul|registration", resource, ignore.case = TRUE) &
        format %in% c("CSV", "XLSX", "XLS")
]
if (nrow(cand)) {
    message("camp population candidates (inspect before use):")
    print(cand[, .(dataset, resource, format, last_modified)])
} else {
    message("no 2025-2026 camp population resource found on HDX; ",
            "camp_population.csv not written")
}

# ------------------------------------------------------------- manifest ----

man <- rbindlist(manifest_rows)
fwrite(man, MANIFEST)
message("wrote ", MANIFEST, ": ", nrow(man), " resources")
