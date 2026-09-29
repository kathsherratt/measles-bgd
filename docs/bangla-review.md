# Bangla review log

Places where the extraction depends on reading Bengali that is garbled, partly legible, or interpreted by a non-Bengali reader (Claude, unreviewed). Each item says what was assumed and how to check it against the PDF. Please record the reviewer's initials and outcome in the last column, and note any correction in `assets/dghs-corrections.csv`.

The DGHS PDFs use a legacy font encoding, so their text layer reads as scrambled Bengali (e.g. `সমরিত রিয়ন্ত্রণ সকন্দ্র` for সমন্বিত নিয়ন্ত্রণ কেন্দ্র) or, on 3 April, as SutonnyMJ ASCII (`MZ 24 N›Uvq`). The printed page is correct; only the text layer is garbled. Always check against the rendered PDF, not the extracted text.

## Priority 1: meaning of columns and measures

| # | Item | What the code assumes | Why uncertain | How to check | Reviewer |
|---|---|---|---|---|---|
| 1 | Layout A column order (4 April to 5 May) | 24h then cumulative: suspected cases, suspected admitted, discharged from hospital, suspected deaths, confirmed cases, confirmed deaths | Read from the legible 6 April header; other dates inferred from arithmetic | Headers on page 2 of 15 April | |
| 2 | Layout B (6 to 9 May) | 24h: suspected, admitted, discharged, confirmed deaths, confirmed, suspected deaths. Cumulative: suspected, admitted, discharged, confirmed, confirmed deaths, suspected deaths | Inferred only from day-to-day arithmetic; headers garbled | Headers on page 2 of 6 May and 8 May | |
| 3 | Layout C (10 May onwards) | Both blocks: suspected, suspected deaths, confirmed, confirmed deaths, admitted, discharged | Inferred from arithmetic and part-legible headers | Headers on page 2 of 10 May and 29 September | |
| 4 | "Suspected deaths" (সন্দেহজনক হাম রোগে মৃত্যু) | Deaths among all suspected cases, including those later confirmed, so suspected deaths are at least confirmed deaths | If the two are disjoint, total deaths are their sum. This changes every CFR. | Heading wording and any note; ask DGHS/WHO if unclear | |
| 5 | "Admitted" (ভর্তি) and "discharged" (ছাড়প্রাপ্ত / ছুটি পাওয়া) | Hospital admissions of suspected cases, and discharges from hospital | Could include outpatients, or only some facilities | Header wording on 6 April and 29 September | |
| 6 | Page 1, first block | Suspected 24h, suspected cumulative, confirmed 24h, confirmed cumulative, cumulative admitted, cumulative discharged | Order inferred from 2 and 15 April and 29 September | Page 1 of 2 April, 1 May, 29 September | |
| 7 | Page 1, second block | First two numbers: deaths in the division and the district with most deaths that day (যে বিভাগে / যে জেলায় মৃত্যু বেশি), with those names printed above. Then two (24h, cumulative) death pairs, confirmed and suspected, whose order swaps between May and September. The code takes the larger cumulative as suspected. | Heading partly legible; the swap was inferred | Page 1 of 3 April, 1 May, 29 September | |

## Priority 2: footnotes

`data/dghs-notes.csv` holds 22 footnotes and 14 starred values, verbatim from the text layer, with empty `translation` and `reviewed_by` columns. Please translate from the PDF, not the CSV. Tentative readings, used in the plan and not yet relied on in code:

| Date | Tentative reading | Why it matters |
|---|---|---|
| 3 April | 5 confirmed deaths removed from the national total as incorrect district reports (Brahmanbaria 3, Laxmipur 1, Chandpur 1); one death at Shaheed Suhrawardy Medical College Hospital added | Explains confirmed deaths falling from 13 to 9 |
| 4 to 8 April | Figures updated; cumulative discharges restated | Early revisions |
| 16 to 20 April | Something about data from 30 upazilas and 13 ... in divisions starting on 5 and 12 April | May describe the MR campaign phases or a reporting change |
| 18 May | Duplicate records at Rajshahi Medical College Hospital removed | Explains the drop of 4,340 suspected cases |
| 23 May | Late 24h data from the Mymensingh civil surgeon's office included | Explains the jump of 995 |
| 7, 10 and 12 May; 30 August | Starred values; notes unread | Probably revisions to confirmed cases and deaths |
| 23 September | Four deaths from the 21st published late because of reporting delay | Direct evidence of death reporting delay |

## Priority 3: labels and dates

| # | Item | What the code assumes | How to check | Reviewer |
|---|---|---|---|---|
| 8 | Division row labels | 37 spellings mapped to 8 divisions plus the total by substring (`division_of()` in `R/02-extract-dghs.R`), e.g. বসরশাে, িনরশাল, বন শাে → Barishal; নসন্দলট, রিললট → Sylhet; সমাট, রমাট, যমাট → total | Spot-check the row order on page 2 of 15 April, 1 May, 29 September | |
| 9 | Release date | Footer date (dd-mm-yyyy) on the last page; slug date where there is none (1 and 2 May, 30 May, 11, 15 and 28 July) | Compare with the header date on page 1 | |
| 10 | Reporting window | 8am previous day to 8am on the release date | Page 1 sentence "... সকাল 8:00 টা থেকে ..." | |
| 11 | Data source line | Until mid-April "MIS, DGHS"; from then "Health Emergency Operation Centre and Control Room, DGHS" | Page 1 source line, 2 and 15 April | |
| 12 | Campaign tables | Not yet labelled. Numbers kept raw in `data/dghs-campaign-raw.csv`. Assumed columns: target, cumulative vaccinated, coverage %; in May also 24h target, 24h vaccinated, 24h coverage | Campaign table headers, 1 May and 29 September | |
| 13 | City corporation rows | Matched on garbled forms of কর্পোরেশন | Page 3 of 29 September | |

## Needs manual transcription

| Date | Problem |
|---|---|
| 6 April | Text layer wraps the Dhaka row over two lines, so the division table cannot be parsed. Transcribe page 2 into `assets/dghs-manual.csv` (not yet created). |
| 3 April | SutonnyMJ encoding on page 1; values parsed but unverified |
