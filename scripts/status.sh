#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/team.conf"

OUTPUT="/var/www/$TEAM/live/status.html"

HOSTNAME=$(hostname)
TIME=$(date '+%Y-%m-%d %H:%M:%S')
UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{print $2}')
MEMORY=$(free -h)
DISK=$(df -h /)

if systemctl is-active --quiet nginx; then
    NGINX="RUNNING"
else
    NGINX="STOPPED"
fi

DISK_PERCENT=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

WARNING=""

if [ "$DISK_PERCENT" -gt 80 ]; then
    WARNING="WARNING: Disk usage is above 80%"
fi

if [ "$NGINX" = "STOPPED" ]; then
    WARNING="$WARNING WARNING: Nginx is not running"
fi

CURRENT_RELEASE=$(readlink /var/www/$TEAM/current)

if [ -f /var/www/$TEAM/deploys.log ]; then
    DEPLOY_LOG=$(tail -n 5 /var/www/$TEAM/deploys.log)
else
    DEPLOY_LOG="No deployment log found"
fi

mkdir -p "$(dirname "$OUTPUT")"

cat <<EOF > "$OUTPUT"
<!DOCTYPE html>
<html>
<head>
    <title>$TEAM Live Status</title>
</head>
<body>
    <h1>$TEAM Server Status</h1>

    <h2>Server Information</h2>
    <p>Hostname: $HOSTNAME</p>
    <p>Page Updated: $TIME</p>
    <p>Uptime: $UPTIME</p>
    <p>Load Average: $LOAD</p>

    <h2>Memory Usage</h2>
    <pre>$MEMORY</pre>

    <h2>Disk Usage</h2>
    <pre>$DISK</pre>

    <h2>Nginx Status</h2>
    <p>$NGINX</p>

<h2>Current Release</h2>
<p>$CURRENT_RELEASE</p>

<h2>Last 5 Deployments</h2>
<pre>$DEPLOY_LOG</pre>

    <h2 style="color:red;">$WARNING</h2>
</body>
</html>
EOF

echo "Status page generated: $OUTPUT"
