#!/usr/bin/env python3
"""
Check proposed parameter values against their source PDFs and add the ones
that pass to the parameter register.

A language model locates passages and proposes rows in
data/parameters/proposals.csv: the verbatim `quote`, and `value_text`, the
part of the quote that holds the number. It is never the source of a number.
This script keeps a proposal only if:
  - the source PDF is found (Zotero storage, by the article's `pdf_key`);
  - the quote is a span of the PDF page's text layer (whitespace squished,
    ligatures and soft hyphens undone, manuscript line numbers ignored);
  - `value_text` occurs exactly once in the quote on number boundaries
    ("1.2" does not count inside "1.22", nor "35" inside "0.35");
  - for a binned row, `bin_text` (e.g. "0-3d") is immediately followed by
    `value_text`, exactly once, so a count cannot be paired with the wrong
    bin.
The value is then parsed from `value_text`: the first number is the value;
with three or more numbers, the last two are the lower and upper bounds.
Numbers in between (a sample size, "95%" in "95% CI") are ignored.
Numbers may carry thousands commas ("2,071") and mid-dot decimals ("12·5");
a dash before a number is a minus sign unless a digit precedes it
("range = –2 to 10" gives -2; "3-6" is a range).
Bin edges stay as checked text in `bin_text`; the script that uses them
parses them.

Python, not R: pymupdf returns each page's text in reading-order blocks, so
two-column journal pages stay readable; pdftools interleaves the columns.
Needs pymupdf (pip install pymupdf).

Outputs:
  data/parameters/measles_parameters.csv  passing rows added or replaced by
                                          id; columns quote, value_text,
                                          via_article_id, pdf_page and
                                          bin_text added
  data/parameters/proposals-rejected.csv  failing proposals with a reason

PDFs are looked up under $ZOTERO_STORAGE (default ~/Zotero/storage). On a
machine without the PDFs every proposal is rejected as "pdf not found" and
the register is left unchanged.

Usage:
    python3 R/parameters/02-check-proposals.py
"""

import csv
import glob
import os
import pathlib
import re

import pymupdf

ROOT = pathlib.Path(__file__).resolve().parents[2]
PARAMS = ROOT / "data" / "parameters"
PROPOSALS = PARAMS / "proposals.csv"
ARTICLES = PARAMS / "measles_articles.csv"
REGISTER = PARAMS / "measles_parameters.csv"
REJECTED = PARAMS / "proposals-rejected.csv"
STORAGE = pathlib.Path(os.environ.get("ZOTERO_STORAGE",
                                      os.path.expanduser("~/Zotero/storage")))
EXTRACTED_BY = "LLM-located quote; value parsed by script; unreviewed"
NEW_COLS = ["quote", "value_text", "via_article_id", "pdf_page", "bin_text"]
NUMBER = re.compile(r"(?:(?<![\d.])[-–−](?=\d))?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?")


def squish(s):
    s = s.replace("ﬁ", "fi").replace("ﬂ", "fl").replace("­", "")
    s = re.sub(r"-\n(\w)", r"\1", s)
    s = re.sub(r"(\d)·(\d)", r"\1.\2", s)
    return re.sub(r"\s+", " ", s).strip()


def page_texts(pdf, page):
    """The page's text twice: as extracted, and with manuscript line numbers
    (a number of up to three digits ending a block) removed."""
    doc = pymupdf.open(pdf)
    if page < 1 or page > len(doc):
        return []
    blocks = [squish(b[4]) for b in doc[page - 1].get_text("blocks", sort=True)]
    plain = " ".join(blocks)
    unnumbered = " ".join(re.sub(r"\s\d{1,3}$", "", b) for b in blocks)
    return [squish(plain), squish(unnumbered)]


def parse(value_text):
    nums = [float(re.sub(r"[–−]", "-", x).replace(",", ""))
            for x in NUMBER.findall(value_text)]
    if not nums:
        return None
    lower = upper = ""
    if len(nums) >= 3:
        lower, upper = nums[-2], nums[-1]
    fmt = lambda x: "" if x == "" else f"{x:g}"
    return fmt(nums[0]), fmt(lower), fmt(upper)


def occurrences(quote, token):
    """Start positions of `token` in `quote` that do not cut through a
    number: "1.2" inside "1.22" or "35" inside "0.35" do not count."""
    hits = []
    for m in re.finditer(re.escape(token), quote):
        before, after = quote[max(m.start() - 1, 0):m.start()], quote[m.end():m.end() + 2]
        if not (re.match(r"[\d.,]", before) or re.match(r"\d|[.,]\d", after)):
            hits.append(m.start())
    return hits


def check(p, pdf_keys):
    key = pdf_keys.get(p["article_id"], "")
    pdfs = glob.glob(str(STORAGE / key / "*.pdf")) if key else []
    if not pdfs:
        return "pdf not found", None
    texts = page_texts(pdfs[0], int(p["pdf_page"]))
    quote = squish(p["quote"])
    if not any(quote in t for t in texts):
        return "quote is not a span of the page text", None
    value_text = squish(p["value_text"])
    if len(occurrences(quote, value_text)) != 1:
        return "value_text does not occur exactly once on number boundaries", None
    # A table row: the count follows its own bin label ("0-3d 2,071")
    if p.get("bin_text") and len(occurrences(quote, squish(p["bin_text"]) + " " + value_text)) != 1:
        return "bin_text and value_text are not adjacent exactly once", None
    parsed = parse(value_text)
    if parsed is None:
        return "no number in value_text", None
    return None, parsed


with open(ARTICLES, newline="") as f:
    pdf_keys = {r["article_id"]: r.get("pdf_key", "") for r in csv.DictReader(f)}
with open(PROPOSALS, newline="") as f:
    proposals = list(csv.DictReader(f))
with open(REGISTER, newline="") as f:
    reader = csv.DictReader(f)
    reg_cols = list(reader.fieldnames)
    register = list(reader)
reg_cols += [c for c in NEW_COLS if c not in reg_cols]

accepted, rejected = [], []
for p in proposals:
    reason, parsed = check(p, pdf_keys)
    if reason:
        rejected.append({**p, "reason": reason})
        continue
    value, lower, upper = parsed
    row = {c: "" for c in reg_cols}
    row.update({
        "id": p["id"], "article_id": p["article_id"], "pathogen": "Measles virus",
        "parameter_type": p["parameter_type"], "parameter_value": value,
        "parameter_unit": p["parameter_unit"],
        "parameter_value_type": p["parameter_value_type"],
        "parameter_uncertainty_type": p["parameter_uncertainty_type"] if lower != "" else "",
        "parameter_uncertainty_lower_value": lower,
        "parameter_uncertainty_upper_value": upper,
        "distribution_type": p["distribution_type"],
        "population_country": p["population_country"],
        "population_location": p["population_location"],
        "population_age_min": p["population_age_min"],
        "population_age_max": p["population_age_max"],
        "population_sample_size": p["population_sample_size"],
        "method_disaggregated_by": p["method_disaggregated_by"],
        "parameter_notes": p["parameter_notes"],
        "source_location": f"PDF page {p['pdf_page']}",
        "quality_flag": p["quality_flag"], "extracted_by": EXTRACTED_BY,
        "quote": squish(p["quote"]), "value_text": squish(p["value_text"]),
        "via_article_id": p["via_article_id"], "pdf_page": p["pdf_page"],
        "bin_text": p.get("bin_text", ""),
    })
    accepted.append(row)

ids = {r["id"] for r in accepted}
merged = [r for r in register if r["id"] not in ids] + accepted
merged.sort(key=lambda r: int(r["id"].lstrip("P")))
with open(REGISTER, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=reg_cols, lineterminator="\n")
    w.writeheader()
    w.writerows({c: r.get(c, "") for c in reg_cols} for r in merged)
with open(REJECTED, "w", newline="") as f:
    cols = list(proposals[0].keys()) + ["reason"] if proposals else ["reason"]
    w = csv.DictWriter(f, fieldnames=cols, lineterminator="\n")
    w.writeheader()
    w.writerows(rejected)

print(f"{len(proposals)} proposals: {len(accepted)} added, {len(rejected)} rejected")
for r in accepted:
    bounds = (f" ({r['parameter_uncertainty_lower_value']}, "
              f"{r['parameter_uncertainty_upper_value']})"
              if r["parameter_uncertainty_lower_value"] != "" else "")
    print(f"  {r['id']} {r['parameter_type']} {r['parameter_value_type']}: "
          f"{r['parameter_value']}{bounds}")
for r in rejected:
    print(f"  rejected {r['id']}: {r['reason']}")
