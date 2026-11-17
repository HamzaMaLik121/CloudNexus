#!/bin/bash

SITE_DIR="${1:-site}"
ERRORS=0

echo "Starting Website Checks..."

# 1. Check HTML titles
while IFS= read -r -d '' file; do
    if ! grep -qiE '<title[^>]*>[^<]*</title>' "$file"; then
        echo "ERROR: Missing title in $file"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find "$SITE_DIR" -type f -name "*.html" -print0)

# 2. Check files larger than 1 MB
while IFS= read -r -d '' file; do
    size=$(stat -c%s "$file")

    if [ "$size" -gt 1048576 ]; then
        echo "ERROR: File larger than 1 MB: $file"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find "$SITE_DIR" -type f -print0)

# 3. Check internal broken links
while IFS= read -r -d '' file; do

    while IFS= read -r link; do

        [[ "$link" =~ ^https?:// ]] && continue
        [[ "$link" =~ ^// ]] && continue
        [[ "$link" =~ ^# ]] && continue
        [[ "$link" == /live/* ]] && continue

        link="${link%%\?*}"
        link="${link%%#*}"

        [ -z "$link" ] && continue

        if [[ "$link" == /* ]]; then
            target="$SITE_DIR$link"
        else
            target="$(dirname "$file")/$link"
        fi

        if [ ! -f "$target" ] && [ ! -d "$target" ]; then
            echo "ERROR: Broken link in $file: $link"
            ERRORS=$((ERRORS + 1))
        fi

    done < <(grep -Eoi '(href|src)="[^"]+"' "$file" | cut -d'"' -f2)

done < <(find "$SITE_DIR" -type f -name "*.html" -print0)

# Final result
if [ "$ERRORS" -gt 0 ]; then
    echo "Website checks failed: $ERRORS problem(s) found."
    exit 1
else
    echo "All checks passed"
    exit 0
fi


# Final result
if [ "$ERRORS" -gt 0 ]; then
    echo "Website checks failed: $ERRORS problem(s) found."
    exit 1
else
    echo "All checks passed"
    exit 0
fi

