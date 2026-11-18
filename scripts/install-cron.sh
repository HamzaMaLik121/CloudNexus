#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="/var/www/cloudnexus"
BIN_DIR="$BASE_DIR/bin"

STATUS_SCRIPT="$BIN_DIR/status.sh"
TRAFFIC_SCRIPT="$BIN_DIR/traffic-report.sh"

if [[ ! -x "$STATUS_SCRIPT" ]]; then
    echo "ERROR: status.sh is missing or not executable."
    exit 1
fi

if [[ ! -x "$TRAFFIC_SCRIPT" ]]; then
    echo "ERROR: traffic-report.sh is missing or not executable."
    exit 1
fi

CRON_STATUS="* * * * * $STATUS_SCRIPT"
CRON_TRAFFIC="*/5 * * * * $TRAFFIC_SCRIPT"

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

UPDATED_CRON="$(
    printf '%s\n' "$CURRENT_CRON" |
        grep -Fv "$STATUS_SCRIPT" |
        grep -Fv "$TRAFFIC_SCRIPT" || true
)"

{
    printf '%s\n' "$UPDATED_CRON"
    printf '%s\n' "$CRON_STATUS"
    printf '%s\n' "$CRON_TRAFFIC"
} | crontab -

echo "Monitoring cron jobs installed successfully."
