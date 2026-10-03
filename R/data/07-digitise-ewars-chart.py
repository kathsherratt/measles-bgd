#!/usr/bin/env python3
"""
Digitise the weekly measles chart in the Rohingya response EWARS bulletin.

The camps' weekly suspected measles/rubella counts are published only as a
bar chart (Figure 4, page 20 of the W36 2026 epidemiological highlights,
data/pdf/context/rohingya_ewars/W36-2026.pdf). The chart is drawn as vector
rectangles, so this script reads each bar's coordinates from the PDF drawing
and converts them with the chart's own axes. No value is read by eye or by
a language model; a person confirms the result against the chart.

Python, not R: the bars are PDF vector paths, which pdftools does not
expose. Needs pymupdf (pip install pymupdf).

How the axes are read:
  - y: the chart was rendered to pixels before it was embedded, so every
    bar height is a whole number of pixels (0.602 points) and one case is
    about 1.43 pixels. A height in pixels is the case count times a scale,
    rounded. Because the scale exceeds one, each pixel height comes from at
    most one whole count. The script searches scales near the gridlines'
    (0 to 400, labels matched to the nearest gridline), offsets and rounding
    rules for those that fit every bar exactly, and keeps the counts only if
    every fit gives the same counts.
  - x: a date axis. Its ticks fall on the first of each month, labelled with
    the MMWR epidemiological week (Sunday to Saturday) containing that day.
    The script checks every label against that reading, fits position
    against date from the ticks, and places each bar on the Saturday nearest
    its centre: bars sit on the last day of their week.

Checks (the script stops if any fails): 21 ticks matched to labels; each
label equals the MMWR week of its month start; gridline fit residuals under
half a point; bar heights whole pixels; at least one exact fit, and every
exact fit giving the same counts; counts within one case of the gridline
reading; bars evenly spaced one week apart; every bar within half a day of
a Saturday; weeks consecutive.

Output: data/camps-ewars-weekly.csv, one row per week, with the pixel
height, the gridline reading before rounding and the bar's coordinates for
checking. `confirmed_by` and `review_note` come from the `ewars-series` row
of data/camps-review.csv, the person's check of the whole series against
the chart.

Usage:
    python3 R/data/07-digitise-ewars-chart.py
"""

import csv
import math
import datetime as dt
import pathlib
import re
import statistics

import pymupdf

ROOT = pathlib.Path(__file__).resolve().parents[2]
PDF = ROOT / "data" / "pdf" / "context" / "rohingya_ewars" / "W36-2026.pdf"
OUT = ROOT / "data" / "camps-ewars-weekly.csv"
REVIEW = ROOT / "data" / "camps-review.csv"
PAGE = 20
SERIES = "Total suspected measles/rubella cases - Cox's Bazar"
BAR_FILL = (0.231, 0.451, 0.886)
GRID = (0.9, 0.9, 0.9)
TICK = (0.8, 0.84, 0.92)


def near(c, target, tol=0.01):
    return bool(c) and all(abs(x - t) < tol for x, t in zip(c, target))


def week_one(year):
    """Sunday starting MMWR week 1: the Sunday-to-Saturday week holding 4 January."""
    jan4 = dt.date(year, 1, 4)
    return jan4 - dt.timedelta(days=(jan4.weekday() + 1) % 7)


def mmwr_week(d):
    year = d.year + 1
    while week_one(year) > d:
        year -= 1
    return year, (d - week_one(year)).days // 7 + 1


def fit(xs, ys):
    """Least-squares line y = a + b x, with residuals."""
    mx, my = statistics.fmean(xs), statistics.fmean(ys)
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / \
        sum((x - mx) ** 2 for x in xs)
    a = my - b * mx
    return a, b, [y - (a + b * x) for x, y in zip(xs, ys)]


page = pymupdf.open(PDF)[PAGE - 1]
drawings = page.get_drawings()
words = page.get_text("words")

# Bars: the chart's blue rectangles standing on the baseline (the legend
# swatch, below the axis, is excluded by its bottom edge)
blue = [d["rect"] for d in drawings if near(d.get("fill"), BAR_FILL)]
baseline = statistics.mode(round(r.y1, 2) for r in blue)
bars = sorted((r for r in blue if round(r.y1, 2) == baseline),
              key=lambda r: r.x0)

# y axis: gridlines and their numeric labels, left of the plot
grid = sorted({round(d["rect"].y0, 2) for d in drawings
               if d["type"] == "s" and near(d.get("color"), GRID)
               and d["rect"].height < 1})
labels = [(float(w[4]), (w[1] + w[3]) / 2) for w in words
          if re.fullmatch(r"\d+", w[4]) and w[2] < 45 and 100 < w[1] < 460]
pairs = [(min(grid, key=lambda g: abs(g - y)), v) for v, y in labels]
a_y, b_y, res_y = fit([g for g, _ in pairs], [v for _, v in pairs])
assert len(pairs) == len(grid) == 9, (len(pairs), len(grid))
per_point = -b_y  # cases per point of bar height
assert max(abs(r) for r in res_y) < 0.5 * per_point, res_y  # half a point

# x axis: ticks below the baseline and their week labels (week over year)
ticks = sorted(round(d["rect"].x0, 2) for d in drawings
               if d["type"] == "s" and near(d.get("color"), TICK)
               and d["rect"].width < 1)
weeks = [w for w in words if re.fullmatch(r"W\d{2}", w[4]) and w[1] > 470]
years = [w for w in words if re.fullmatch(r"20\d{2}", w[4]) and 455 < w[1] < 478]
tick_labels = []
for t in ticks:
    wk = min(weeks, key=lambda w: abs((w[0] + w[2]) / 2 - t))
    yr = min(years, key=lambda w: abs((w[0] + w[2]) / 2 - t))
    assert abs((wk[0] + wk[2]) / 2 - t) < 3, (t, wk)
    tick_labels.append((t, int(yr[4]), int(wk[4][1:])))
assert len(tick_labels) == 21, len(tick_labels)

# Ticks are month starts from January 2025; each label must be the MMWR
# week of its month start
starts = [dt.date(2025 + (i // 12), i % 12 + 1, 1) for i in range(21)]
for (t, yr, wk), d in zip(tick_labels, starts):
    assert mmwr_week(d) == (yr, wk), (d, mmwr_week(d), yr, wk)
origin = starts[0]
a_x, b_x, res_x = fit([(d - origin).days for d in starts],
                      [t for t, _, _ in tick_labels])
assert max(abs(r) for r in res_x) < 1.5, res_x  # points; ticks snap to pixels

# Bar heights in pixels: the smallest step between distinct heights is one
# pixel, and every height is a whole number of them
heights = sorted({r.y1 - r.y0 for r in bars})
pixel = min(b - a for a, b in zip(heights, heights[1:]) if b - a > 0.1)
pixels = [(r.y1 - r.y0) / pixel for r in bars]
assert all(abs(h - round(h)) < 0.05 for h in pixels), pixels
pixels = [round(h) for h in pixels]

# Counts: every scale (pixels per case, within 1% of the gridlines'),
# offset and rounding rule that reproduces every bar height exactly
ROUNDING = {"round": lambda x: math.floor(x + 0.5), "floor": math.floor,
            "ceil": math.ceil}


def exact_counts(scale, offset, rounding):
    counts = []
    for h in pixels:
        guess = round((h - offset) / scale)
        hits = [v for v in range(max(0, guess - 2), guess + 3)
                if ROUNDING[rounding](scale * v + offset) == h]
        if len(hits) != 1:
            return None
        counts.append(hits[0])
    return tuple(counts)


grid_scale = 1 / (per_point * pixel)
solutions = {}
for i in range(-1000, 1001):
    scale = grid_scale * (1 + i / 100000)
    for j in range(21):
        for rounding in ROUNDING:
            counts = exact_counts(scale, -0.5 + j / 20, rounding)
            if counts:
                solutions.setdefault(counts, []).append(scale)
assert len(solutions) == 1, f"{len(solutions)} distinct exact fits"
counts, scales = next(iter(solutions.items()))
gridline_reading = [(r.y1 - r.y0) * per_point for r in bars]
assert all(abs(v - g) < 1 for v, g in zip(counts, gridline_reading))

# Bars one week apart, each on a Saturday
# Bar positions snap to pixels too, so they are dated from a straight line
# through all bar centres rather than one by one
centres = [(r.x0 + r.x1) / 2 for r in bars]
a_c, pitch, res_c = fit(list(range(len(bars))), centres)
assert abs(pitch / (7 * b_x) - 1) < 0.01, pitch
assert max(abs(x) for x in res_c) < pixel, res_c
rows = []
for i, (r, c, v, h, g) in enumerate(zip(bars, centres, counts, pixels,
                                        gridline_reading)):
    day = (a_c + pitch * i - a_x) / b_x
    # Nearest Saturday: the origin, 1 January 2025, is a Wednesday, so
    # Saturdays fall at days 3 + 7k
    sat_day = 3 + 7 * round((day - 3) / 7)
    offset = day - sat_day
    assert abs(offset) < 0.5, (c, day, offset)
    week_end = origin + dt.timedelta(days=sat_day)
    year, week = mmwr_week(week_end)
    rows.append({
        "source": "rohingya_ewars", "doc_id": "W36-2026", "page": PAGE,
        "series": SERIES, "epi_year": year, "epi_week": week,
        "week_start": (week_end - dt.timedelta(days=6)).isoformat(),
        "week_end": week_end.isoformat(), "value": v,
        "bar_pixels": h, "gridline_reading": f"{g:.2f}",
        "bar_x": f"{c:.2f}", "bar_top": f"{r.y0:.2f}",
        "bar_bottom": f"{r.y1:.2f}", "date_offset_days": f"{offset:.2f}",
        "confirmed_by": "", "review_note": ""})

# The person's check of the series, if made
with open(REVIEW, newline="") as f:
    review = {r["key"]: r for r in csv.DictReader(f)}.get("ewars-series")
if review and review["decision"] == "confirmed":
    for r in rows:
        r["confirmed_by"] = review["reviewed_by"]
        r["review_note"] = review["note"]

# Weeks are consecutive
ends = [dt.date.fromisoformat(r["week_end"]) for r in rows]
assert all((b - a).days == 7 for a, b in zip(ends, ends[1:]))

with open(OUT, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)

print(f"{len(rows)} weeks, {rows[0]['epi_year']} W{rows[0]['epi_week']:02d} "
      f"to {rows[-1]['epi_year']} W{rows[-1]['epi_week']:02d}")
print(f"cases per point {per_point:.4f}; gridline residuals (cases) "
      f"{max(abs(r) for r in res_y):.3f}; tick residuals (points) "
      f"{max(abs(r) for r in res_x):.2f}")
print(f"pixel {pixel:.4f} points; exact fits {len(scales)}, scale "
      f"{min(scales):.4f} to {max(scales):.4f} pixels per case, all giving "
      "the same counts")
print("largest gap between count and gridline reading: "
      f"{max(abs(float(r['gridline_reading']) - r['value']) for r in rows):.2f}")
print("bar offsets from Saturday (days): "
      f"{min(float(r['date_offset_days']) for r in rows):.2f} to "
      f"{max(float(r['date_offset_days']) for r in rows):.2f}")
print(f"wrote {OUT.relative_to(ROOT)}")
