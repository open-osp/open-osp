#!/bin/bash
# Reload the MariaDB timezone tables (mysql.time_zone*) from the db container's /usr/share/zoneinfo,
# which is mounted read-only from the host (see the db service in docker-compose.yml).
#
# Run this after the host's tzdata package has been updated (e.g. `apt-get install --only-upgrade tzdata`).
# The db container is restarted at the end so mysqld drops cached zone definitions.
# This briefly interrupts database connections: DO NOT run during production hours.
#
# Usage: ./openosp tzdata [--no-restart]

set -e

if [ -f "local.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source local.env
    set +a
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Run a query in the db container. The root password is read from the container's own environment.
db_query() {
    docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B "$@"' sh "$@"
}

zoneinfo_version() {
    # tzdata.zi is shipped by Debian/Ubuntu tzdata packages; its first line is "# version YYYYx".
    docker compose exec -T db sh -c 'head -n1 /usr/share/zoneinfo/tzdata.zi 2>/dev/null || echo "unknown"'
}

RESTART=1
if [ "$1" = "--no-restart" ]; then
    RESTART=0
fi

if [ -z "$(docker compose ps -q db)" ]; then
    log "ERROR: the db container is not running. Start it with: docker compose up -d db"
    exit 1
fi

if ! docker compose exec -T db test -f /usr/share/zoneinfo/America/Vancouver; then
    log "ERROR: /usr/share/zoneinfo in the db container is missing or incomplete."
    log "Check that the host has tzdata installed and that the db service has been recreated: docker compose up -d db"
    exit 1
fi

log "Host zoneinfo seen by db container: $(zoneinfo_version)"
log "Time zones loaded before update: $(db_query -e 'SELECT COUNT(*) FROM mysql.time_zone_name')"

log "Reloading mysql.time_zone* tables from /usr/share/zoneinfo..."
# Warnings about non-zone files (zone.tab, iso3166.tab, etc.) are expected and suppressed.
docker compose exec -T db sh -c \
    'mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot mysql'

log "Time zones loaded after update: $(db_query -e 'SELECT COUNT(*) FROM mysql.time_zone_name')"

if [ "$RESTART" -eq 1 ]; then
    log "Restarting db so cached time zone definitions are dropped..."
    docker compose restart db

    for _ in $(seq 1 60); do
        if docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin -uroot ping' >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
else
    log "Skipping restart (--no-restart). Restart db later for the new rules to take full effect."
fi

RESULT=$(db_query -e "SELECT @@system_time_zone, @@time_zone, NOW(), CONVERT_TZ(UTC_TIMESTAMP(), 'UTC', 'America/Vancouver')")
log "system_time_zone, time_zone, NOW(), CONVERT_TZ(UTC->America/Vancouver): $RESULT"

if echo "$RESULT" | grep -q "NULL"; then
    log "ERROR: CONVERT_TZ returned NULL; the time zone tables did not load correctly."
    exit 1
fi

log "Database tzdata update complete."
