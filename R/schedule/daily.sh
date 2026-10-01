#!/bin/zsh
# Daily download: DGHS platform dashboard and press-release (sitrep) extract.
#
# Run by launchd (R/schedule/uk.kathsherratt.measles-bgd.daily.plist) at 12:30
# London time, after the platform publishes (16:41 Dhaka, 11:41 BST).
# Fetches the dashboard from the last date already held (refetching it as a
# check), tidies, then fetches, extracts and cross-checks the press releases.
# Steps run in order; a failure stops the run and is in the log.
#
# Usage:
#     R/schedule/daily.sh
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

ROOT="${0:A:h:h:h}"
cd "$ROOT"
mkdir -p outputs/logs
LOG="outputs/logs/daily_$(date +%F-%H%M).log"
exec > "$LOG" 2>&1

# Skip if a fetch is already running (never edit or rerun under a live script).
if pgrep -f "R/data/01-fetch-dashboard.R" > /dev/null; then
    echo "01-fetch-dashboard.R already running; skipping"
    exit 0
fi

FROM=$(Rscript -e 'x <- data.table::fread(here::here("data","dghs-dashboard.csv"), select = "date"); cat(format(max(as.Date(x$date))))')
TO=$(date +%F)
echo "$(date '+%F %T') dashboard $FROM to $TO"

run() { echo "$(date '+%F %T') $*"; caffeinate -is Rscript "$@"; }
run R/data/01-fetch-dashboard.R --from "$FROM" --to "$TO"
run R/data/02-tidy-dashboard.R
run sitrep/R/01-fetch.R
run sitrep/R/02-extract.R
run sitrep/R/03-compare-dashboard.R
echo "$(date '+%F %T') done"
