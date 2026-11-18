#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="/var/www/cloudnexus"
RELEASES_DIR="$BASE_DIR/releases"
CURRENT_LINK="$BASE_DIR/current"
DEPLOY_LOG="$BASE_DIR/deploys.log"

ACTOR="${1:-unknown}"

if [[ ! -L "$CURRENT_LINK" ]]; then
    echo "ERROR: Current release link does not exist."
    exit 1
fi

CURRENT_RELEASE="$(readlink -f "$CURRENT_LINK")"

if [[ ! -d "$CURRENT_RELEASE" ]]; then
    echo "ERROR: Current release directory is missing."
    exit 1
fi

PREVIOUS_RELEASE="$(
    find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d \
        ! -name '.*' ! -samefile "$CURRENT_RELEASE" \
        -printf '%T@ %p\n' |
        sort -nr |
        head -n 1 |
        cut -d' ' -f2-
)"

if [[ -z "$PREVIOUS_RELEASE" || ! -d "$PREVIOUS_RELEASE" ]]; then
    echo "ERROR: No previous release available."
    exit 1
fi

TEMP_LINK="$BASE_DIR/current.rollback"

rm -f "$TEMP_LINK"
ln -s "$PREVIOUS_RELEASE" "$TEMP_LINK"
mv -Tf "$TEMP_LINK" "$CURRENT_LINK"

ROLLBACK_TIME="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo "$ROLLBACK_TIME | ROLLBACK | $ACTOR | $PREVIOUS_RELEASE" >> "$DEPLOY_LOG"

echo "Rollback successful!"
echo "Previous release restored: $PREVIOUS_RELEASE"
