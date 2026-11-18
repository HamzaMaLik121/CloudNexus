
#!/usr/bin/env bash
set -Eeuo pipefail

# CloudNexus Deployment Script
# Usage: sudo bash deploy.sh COMMIT_SHA

BASE_DIR="/var/www/cloudnexus"
RELEASES_DIR="$BASE_DIR/releases"
STAGING_DIR="$BASE_DIR/staging"
CURRENT_LINK="$BASE_DIR/current"
SITE_DIR="$STAGING_DIR/site"
CHECK_SCRIPT="$STAGING_DIR/scripts/check-site.sh"

COMMIT_SHA="${1:-}"

# Validate commit SHA
if [[ ! "$COMMIT_SHA" =~ ^[a-f0-9]{40}$ ]]; then
    echo "ERROR: A valid 40-character commit SHA is required."
    exit 1
fi

RELEASE_DIR="$RELEASES_DIR/$COMMIT_SHA"
TEMP_RELEASE="$RELEASES_DIR/.${COMMIT_SHA}.tmp"
TEMP_LINK="$BASE_DIR/current.new"

echo "=================================="
echo "CloudNexus Deployment"
echo "Commit: $COMMIT_SHA"
echo "=================================="

# Verify staging files
if [[ ! -d "$SITE_DIR" || ! -f "$SITE_DIR/index.html" ]]; then
    echo "ERROR: Staged website is missing."
    exit 1
fi

if [[ ! -x "$CHECK_SCRIPT" ]]; then
    echo "ERROR: Website validation script is missing or not executable."
    exit 1
fi

mkdir -p "$RELEASES_DIR"

if [[ -e "$RELEASE_DIR" ]]; then
    echo "ERROR: This release already exists."
    exit 1
fi

# Prepare temporary release
rm -rf "$TEMP_RELEASE"
mkdir "$TEMP_RELEASE"

cp -a "$SITE_DIR/." "$TEMP_RELEASE/"

# Insert deployment version
find "$TEMP_RELEASE" -type f -name '*.html' \
    -exec sed -i "s/__VERSION__/$COMMIT_SHA/g" {} +

# Validate before activating
if ! "$CHECK_SCRIPT" "$TEMP_RELEASE"; then
    echo "ERROR: Validation failed. Previous release remains active."
    rm -rf "$TEMP_RELEASE"
    exit 1
fi

# Move validated release into final location
mv "$TEMP_RELEASE" "$RELEASE_DIR"

# Atomically switch the active release
rm -f "$TEMP_LINK"
ln -s "$RELEASE_DIR" "$TEMP_LINK"
mv -Tf "$TEMP_LINK" "$CURRENT_LINK"

echo "=================================="
echo "Deployment successful!"
echo "Active release: $RELEASE_DIR"
echo "=================================="



# Install deploy user's cron jobs
DEPLOY_CRON=$(mktemp)

(crontab -u deploy -l 2>/dev/null || true) |
    grep -Fv "/var/www/cloudnexus/bin/status.sh" |
    grep -Fv "/var/www/cloudnexus/bin/traffic-report.sh" \
    > "$DEPLOY_CRON" || true

printf '%s\n' \
    '* * * * * /var/www/cloudnexus/bin/status.sh' \
    '*/5 * * * * /var/www/cloudnexus/bin/traffic-report.sh' \
    >> "$DEPLOY_CRON"

crontab -u deploy "$DEPLOY_CRON"
rm -f "$DEPLOY_CRON"

echo "Team scripts and deploy cron jobs installed successfully."
