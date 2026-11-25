#!/bin/bash
# Copy the DB_ADMIN_USER and DB_ADMIN_PASSWORD key/value pairs from local.env into a text file,
# e.g. to hand the credentials to a DBA or import them into a password manager.
#
# The file is created owner-read/write only (600). If it already exists the pairs are appended
# to the end; nothing is overwritten. Delete the file once the credentials have been handed off.
#
# Usage: ./bin/export-db-admin-credentials.sh [output-file]
#        default output-file: db-admin-credentials.txt (git-ignored)

set -euo pipefail

ENV_FILE="local.env"
OUTPUT_FILE="${1:-db-admin-credentials.txt}"
KEYS=(DB_ADMIN_USER DB_ADMIN_PASSWORD)

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. Run this from the OpenOSP directory." >&2
    exit 1
fi

# Collect the lines first so a missing key leaves no partial output file behind.
LINES=()
for key in "${KEYS[@]}"; do
    # Last definition wins, matching how `source local.env` resolves duplicates.
    line=$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV_FILE" | tail -n 1 || true)
    if [ -z "$line" ]; then
        echo "ERROR: $key is not set in $ENV_FILE. Create the user first with: ./openosp dbadmin" >&2
        exit 1
    fi
    # Normalise to plain KEY=value (drop leading whitespace and any "export ").
    line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//')
    LINES+=("$line")
done

if [ -e "$OUTPUT_FILE" ] && [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: $OUTPUT_FILE exists and is not a regular file." >&2
    exit 1
fi

# umask 077: a newly created file is readable by its owner only.
(
    umask 077
    printf '%s\n' "${LINES[@]}" >> "$OUTPUT_FILE"
)
chmod 600 "$OUTPUT_FILE"

echo "Appended ${KEYS[*]} to $OUTPUT_FILE"
