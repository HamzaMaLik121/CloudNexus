
#!/usr/bin/env bash
set -Eeuo pipefail

# CloudNexus deployment script
# Usage: deploy.sh COMMIT_SHA PUSHED_BY DEPLOY_TIME

BASE_DIR="/var/www/cloudnexus"
RELEASES_DIR="$BASE_DIR/releases"
STAGING_DIR="$BASE_DIR/staging"
BIN_DIR="$BASE_DIR/bin"
CURRENT_LINK="$BASE_DIR/current"

SITE_DIR="$STAGING_DIR/site"
SCRIPTS_DIR="$STAGING_DIR/scripts"
CHECK_SCRIPT="$SCRIPTS_DIR/check-site.sh"
DEPLOY_LOG="$BASE_DIR/deploys.log"

COMMIT_SHA="${1:-}"
PUSHED_BY="${2:-unknown}"
DEPLOY_TIME="${3:-$(date -u '+%Y-%m-%d %H:%M:%S UTC')}"

if [[ ! "$COMMIT_SHA" =~ ^[a-f0-9]{40}$ ]]; then
    echo "ERROR: Invalid commit SHA."
    exit 1
fi

# Verify required staged files
for file in \
    "$SITE_DIR/index.html" \
    "$CHECK_SCRIPT" \
    "$SCRIPTS_DIR/status.sh" \
    "$SCRIPTS_DIR/traffic-report.sh" \
    "$SCRIPTS_DIR/rollback.sh" \
    "$SCRIPTS_DIR/team.conf" \
    "$SCRIPTS_DIR/install-cron.sh"
do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file missing: $file"
        exit 1
    fi
done

if [[ ! -x "$CHECK_SCRIPT" ]]; then
    echo "ERROR: check-site.sh is not executable."
    exit 1
fi

mkdir -p "$RELEASES_DIR" "$BIN_DIR"

RELEASE_NAME="$(date -u '+%Y%m%d-%H%M%S')-${COMMIT_SHA}"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_NAME"
TEMP_RELEASE="$RELEASES_DIR/.${RELEASE_NAME}.tmp"
TEMP_LINK="$BASE_DIR/current.new"

echo "Deploying commit: $COMMIT_SHA"
echo "Pushed by: $PUSHED_BY"
echo "Deployment time: $DEPLOY_TIME"

# Prepare and validate website release
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

# Install monitoring and rollback scripts
cp "$SCRIPTS_DIR/status.sh" "$BIN_DIR/status.sh"
cp "$SCRIPTS_DIR/traffic-report.sh" "$BIN_DIR/traffic-report.sh"
cp "$SCRIPTS_DIR/rollback.sh" "$BIN_DIR/rollback.sh"
cp "$SCRIPTS_DIR/team.conf" "$BIN_DIR/team.conf"
cp "$SCRIPTS_DIR/install-cron.sh" "$BIN_DIR/install-cron.sh"

chmod 755 \
    "$BIN_DIR/status.sh" \
    "$BIN_DIR/traffic-report.sh" \
    "$BIN_DIR/rollback.sh" \
    "$BIN_DIR/install-cron.sh"

chmod 644 "$BIN_DIR/team.conf"

# Install required monitoring cron jobs
bash "$BIN_DIR/install-cron.sh"

# Activate new website release
ln -s "$RELEASE_DIR" "$TEMP_LINK"
mv -Tf "$TEMP_LINK" "$CURRENT_LINK"

# Record deployment
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
