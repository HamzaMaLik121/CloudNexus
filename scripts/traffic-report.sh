#!/usr/bin/env bash
# traffic-report.sh - A12: writes the traffic report page from the Nginx access log.
# Reads  /var/log/nginx/TEAM.access.log
# Writes /var/www/TEAM/live/report.html   (runs every 5 minutes from cron)
# Requests for /live/ pages are left out of every number.

set -eu

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/team.conf"                       # sets TEAM and DOMAIN

LOG="${LOG:-/var/log/nginx/${TEAM}.access.log}"
OUT="${OUT:-/var/www/${TEAM}/live/report.html}"

if [ ! -r "$LOG" ]; then
  echo "traffic-report: cannot read $LOG" >&2
  exit 1
fi

TMP="$(mktemp "$(dirname "$OUT")/.report.XXXXXX")"
DATA="$(mktemp)"
trap 'rm -f "$TMP" "$DATA"' EXIT

# 1. Parse the log into: ip <TAB> path <TAB> status (no /live/ pages, no query strings)
awk -F'"' '
  NF >= 3 {
    split($1, a, " "); ip = a[1]
    split($2, r, " "); path = r[2]
    split($3, s, " "); status = s[1]
    sub(/\?.*/, "", path)
    if (ip == "" || path == "" || status !~ /^[0-9][0-9][0-9]$/) next
    if (path ~ /^\/live(\/|$)/) next
    print ip "\t" path "\t" status
  }' "$LOG" > "$DATA"

# 2. Numbers
TOTAL="$(wc -l < "$DATA" | tr -d ' ')"
NOTFOUND="$(awk -F'\t' '$3 == 404' "$DATA" | wc -l | tr -d ' ')"

# Visitors control what is in the log, so escape everything before it goes into HTML
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# Reads values on stdin, prints the 5 most common as table rows
top5() {
  sort | uniq -c | sort -rn | head -5 | while read -r count value; do
    printf '<tr><td>%s</td><td>%s</td></tr>\n' "$(printf '%s' "$value" | esc)" "$count"
  done
}

PAGES="$(cut -f2 "$DATA" | top5)"
VISITORS="$(cut -f1 "$DATA" | top5)"
MISSING="$(awk -F'\t' '$3 == 404 { print $2 }' "$DATA" | top5)"

NONE='<tr><td colspan="2">none yet</td></tr>'
[ -n "$PAGES" ]    || PAGES="$NONE"
[ -n "$VISITORS" ] || VISITORS="$NONE"
[ -n "$MISSING" ]  || MISSING="$NONE"

# 3. Write the page (to a temp file first, then move it into place)
cat > "$TMP" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Traffic report | ${TEAM}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    .totals { display: flex; gap: 1rem; flex-wrap: wrap; }
    .totals div { border: 1px solid #8884; padding: .75rem 1.25rem; }
    .totals strong { display: block; font-size: 2rem; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 1.5rem; }
    th, td { text-align: left; padding: .35rem .6rem; border-bottom: 1px solid #8884; }
    td:last-child, th:last-child { text-align: right; width: 6rem; }
    td:first-child { word-break: break-all; }
    small { opacity: .7; }
  </style>
</head>
<body>
  <h1>Traffic report</h1>
  <p><small>${TEAM} &middot; updated $(date '+%Y-%m-%d %H:%M:%S') &middot; /live/ pages not counted</small></p>

  <div class="totals">
    <div><strong>${TOTAL}</strong>total requests</div>
    <div><strong>${NOTFOUND}</strong>404 Not Found</div>
  </div>

  <h2>Top 5 pages</h2>
  <table><tr><th>Page</th><th>Requests</th></tr>
${PAGES}
  </table>

  <h2>Top 5 visitors</h2>
  <table><tr><th>IP address</th><th>Requests</th></tr>
${VISITORS}
  </table>

  <h2>Top 5 missing pages (404)</h2>
  <table><tr><th>Page</th><th>Requests</th></tr>
${MISSING}
  </table>
</body>
</html>
HTML

chmod 644 "$TMP"
mv -f "$TMP" "$OUT"
