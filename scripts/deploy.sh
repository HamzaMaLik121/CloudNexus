
#!/usr/bin/env bash
set -Eeuo pipefail

# CloudNexus deployment script
# Usage: deploy.sh COMMIT_SHA PUSHED_BY DEPLOY_TIME

BASE_DIR="/var/www/cloudnexus"
RELEASES_DIR="$BASE_DIR/releases"
STAGING_DIR="$BASE_DIR/staging"
CURRENT_LINK="$BASE_DIR/current"
SITE_DIR="$STAGING_DIR/site"
CHECK_SCRIPT="$STAGING_DIR/scripts/check-site.sh"
DEPLOY_LOG="$BASE_DIR/deploys.log"

COMMIT_SHA="${1:-}"
PUSHED_BY="${2:-unknown}"
DEPLOY_TIME="${3:-$(date -u '+%Y-%m-%d %H:%M:%S UTC')}"

if [[ ! "$COMMIT_SHA" =~ ^[a-f0-9]{40}$ ]]; then
    echo "ERROR: Invalid commit SHA."
    exit 1
fi

mkdir -p "$RELEASES_DIR"

RELEASE_NAME="$(date -u '+%Y%m%d-%H%M%S')-${COMMIT_SHA}"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_NAME"
TEMP_RELEASE="$RELEASES_DIR/.${RELEASE_NAME}.tmp"
TEMP_LINK="$BASE_DIR/current.new"

echo "Deploying commit: $COMMIT_SHA"
echo "Pushed by: $PUSHED_BY"
echo "Deployment time: $DEPLOY_TIME"

if [[ ! -d "$SITE_DIR" || ! -f "$SITE_DIR/index.html" ]]; then
    echo "ERROR: Staged website is missing."
    exit 1
fi

if [[ ! -x "$CHECK_SCRIPT" ]]; then
    echo "ERROR: check-site.sh is missing or not executable."
    exit 1
fi

rm -rf "$TEMP_RELEASE"
mkdir "$TEMP_RELEASE"

cp -a "$SITE_DIR/." "$TEMP_RELEASE/"

VERSION="${COMMIT_SHA} - by ${PUSHED_BY} - at ${DEPLOY_TIME}"

find "$TEMP_RELEASE" -type f -name '*.html' \
    -exec sed -i "s|__VERSION__|${VERSION}|g" {} +

if ! "$CHECK_SCRIPT" "$TEMP_RELEASE"; then
    echo "ERROR: Website validation failed."
    rm -rf "$TEMP_RELEASE"
    exit 1
fi

mv "$TEMP_RELEASE" "$RELEASE_DIR"

ln -s "$RELEASE_DIR" "$TEMP_LINK"
mv -Tf "$TEMP_LINK" "$CURRENT_LINK"

echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') | $COMMIT_SHA | $PUSHED_BY | $RELEASE_DIR" >> "$DEPLOY_LOG"

# Keep only the five newest releases
find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.*' -printf '%T@ %p\n' |
    sort -nr |
    tail -n +6 |
    cut -d' ' -f2- |
    while IFS= read -r old_release; do
        rm -rf -- "$old_release"
    done

echo "Deployment successful!"
echo "Active release: $RELEASE_DIR"

