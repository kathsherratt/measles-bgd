# CLAUDE.md (sitrep/)

Rules for the DGHS press-release extraction. Root `CLAUDE.md` rules apply too. This folder is self-contained: it reads its own PDFs and writes under `sitrep/data/`. The main pipeline reads it only through the named exports in `sitrep/README.md`.

Run scripts from the project root with `Rscript sitrep/R/NN-....R`; paths use `here::here()`.

## Bengali

The DGHS PDFs' text layer is garbled by a legacy font encoding, and Claude does not read Bengali reliably. Every reading that is inferred rather than certain (row labels, column meanings, footnotes, dates, campaign headers) goes in `sitrep/docs/bangla-review.md` with what was assumed and how to check it. Bengali-speaking reviewers work from that file. Never silently resolve a Bengali ambiguity in code.

## Things that are easy to get wrong in `sitrep/R/02-extract.R`

- The division table has three column layouts (A: 4 April to 5 May, B: 6 to 9 May, C: 10 May on). The layout is chosen per release by `layout_ok()` against the total row, not by date. Changing that function changes every value.
- The date of record is the footer date, not the URL slug.
- Hand corrections go in `sitrep/assets/corrections.csv` with reason and evidence. Do not patch values in code.
- Failed continuity checks are often real DGHS revisions (explained in footnotes, `sitrep/data/dghs-notes.csv`). Record them; do not "fix" them.
- Whether suspected deaths include confirmed deaths is unresolved (`sitrep/docs/bangla-review.md` item 4), though WHO's total of about 1,100 deaths points to separate counts. Severity outputs carry both readings.

## Hard rules

- No language model is the source of a number or date taken from the PDFs. Extraction is by script from the text layer. An LLM may locate a passage and propose its verbatim quote; the script keeps the quote only if it is a span of the text layer, and parses the value or date from it. A person confirms.
- Never commit `sitrep/data/dghs-*.csv`, `sitrep/data/pdf/` or `sitrep/data/quarantine/`. `sitrep/data/manifest-dghs.csv` (source URLs and hashes) is tracked.
- Never edit a script while a detached `Rscript` is running it.
