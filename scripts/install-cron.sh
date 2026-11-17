#!/bin/bash

PROJECT_DIR="/home/sameer/CloudNexus"
SCRIPT="$PROJECT_DIR/scripts/check-site.sh"
SITE="$PROJECT_DIR/site"
LOG="$PROJECT_DIR/website-check.log"

CRON_JOB="0 9 * * * $SCRIPT $SITE >> $LOG 2>&1"

(crontab -l 2>/dev/null | grep -Fv "$SCRIPT"; echo "$CRON_JOB") | crontab -

echo "Cron job installed successfully."
