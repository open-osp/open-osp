#!/bin/bash
# Create (or bring up to date) a MariaDB administrative user with limited privileges.
#
# The user can do the routine DBA work an OpenOSP deployment needs without being root:
#   - read/write and migrate the application schemas (oscar, drugref2, OscarFax by default):
#     run OSCAR update scripts, create/alter/drop tables, indexes, views, routines, triggers, events
#   - take consistent backups (mysqldump: SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT)
#   - maintenance: ANALYZE / OPTIMIZE / CHECK / REPAIR TABLE
#   - monitoring: SHOW PROCESSLIST for all sessions, SHOW BINLOG/replication status
#
# It deliberately does NOT get:
#   - any access to the `mysql` system schema (cannot read password hashes or edit grants)
#   - SUPER, GRANT OPTION, CREATE USER, FILE, SHUTDOWN, RELOAD, CONNECTION ADMIN or ALL PRIVILEGES
#   - privileges on any database other than those listed in DB_ADMIN_DATABASES
#
# Safe to run repeatedly: on a fresh install, as part of `./openosp bootstrap`, or against an
# already-deployed db container. Every run resets the user's grants to exactly the set below and
# re-applies the password from local.env, so editing DB_ADMIN_PASSWORD and re-running rotates it.
#
# Settings (read from local.env; generated/appended there if missing):
#   DB_ADMIN_USER       user name                          (default: dbadmin)
#   DB_ADMIN_PASSWORD   password                           (default: random, 24 chars)
#   DB_ADMIN_HOST       host part of the account           (default: %  - any host on the docker network
#                       or via the published 3306 port; restrict e.g. to 172.% or 10.0.0.5 if possible)
#   DB_ADMIN_DATABASES  space-separated schemas to manage  (default: "oscar drugref2 OscarFax")
#
# Usage: ./openosp dbadmin            create/update the user
#        ./openosp dbadmin --show     print the user's current grants and exit

set -euo pipefail

ENV_FILE="local.env"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

if [ ! -f "$ENV_FILE" ]; then
    log "ERROR: $ENV_FILE not found. Run this from the OpenOSP directory after ./openosp setup."
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "./$ENV_FILE"
set +a

# Run SQL from stdin as root inside the db container. The root password comes from the
# container's own environment, so it never appears on the host command line.
db_root() {
    docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B "$@"' sh "$@"
}

# Escape a value for use inside a single-quoted SQL string literal.
sql_quote() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"
}

# Append KEY=VALUE to local.env unless the key is already defined there.
persist_setting() {
    if ! grep -q "^$1=" "$ENV_FILE"; then
        printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"
        log "Saved $1 to $ENV_FILE"
    fi
}

DB_ADMIN_USER="${DB_ADMIN_USER:-dbadmin}"
DB_ADMIN_HOST="${DB_ADMIN_HOST:-%}"
DB_ADMIN_DATABASES="${DB_ADMIN_DATABASES:-oscar drugref2 OscarFax}"

if ! [[ "$DB_ADMIN_USER" =~ ^[A-Za-z0-9_]{1,32}$ ]]; then
    log "ERROR: DB_ADMIN_USER must be 1-32 characters of letters, digits or underscore."
    exit 1
fi
if [ "$DB_ADMIN_USER" = "root" ] || [ "$DB_ADMIN_USER" = "${MYSQL_USER:-oscar}" ]; then
    log "ERROR: DB_ADMIN_USER must not be an existing application account ($DB_ADMIN_USER)."
    exit 1
fi

for db in $DB_ADMIN_DATABASES; do
    if ! [[ "$db" =~ ^[A-Za-z0-9]+$ ]]; then
        # Underscores and % are wildcards in database-level grants; refuse rather than over-grant.
        log "ERROR: unsupported database name '$db' in DB_ADMIN_DATABASES (letters and digits only)."
        exit 1
    fi
done

if [ -z "$(docker compose ps -q db)" ]; then
    log "Starting db container..."
    docker compose up -d db
fi

log "Waiting for the database to accept connections..."
for i in $(seq 1 60); do
    if docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin -uroot ping' >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 60 ]; then
        log "ERROR: database did not become ready. Check: docker compose logs db"
        exit 1
    fi
    sleep 2
done

ACCOUNT="'$(sql_quote "$DB_ADMIN_USER")'@'$(sql_quote "$DB_ADMIN_HOST")'"

if [ "${1:-}" = "--show" ]; then
    echo "SHOW GRANTS FOR $ACCOUNT;" | db_root
    exit 0
fi

if [ -z "${DB_ADMIN_PASSWORD:-}" ]; then
    DB_ADMIN_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9')
    DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:0:24}"
    log "Generated a new password for $DB_ADMIN_USER"
fi
persist_setting DB_ADMIN_USER "$DB_ADMIN_USER"
persist_setting DB_ADMIN_PASSWORD "$DB_ADMIN_PASSWORD"

# Privileges per application schema. Covers schema migrations, data fixes, backups and maintenance.
DB_PRIVS="SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES,
  CREATE TEMPORARY TABLES, LOCK TABLES, CREATE VIEW, SHOW VIEW,
  CREATE ROUTINE, ALTER ROUTINE, EXECUTE, TRIGGER, EVENT"

# Server-wide, read-only monitoring privileges (MariaDB 10.5: REPLICATION CLIENT == BINLOG MONITOR).
GLOBAL_PRIVS="PROCESS, REPLICATION CLIENT"

{
    echo "CREATE USER IF NOT EXISTS $ACCOUNT IDENTIFIED BY '$(sql_quote "$DB_ADMIN_PASSWORD")';"
    echo "ALTER USER $ACCOUNT IDENTIFIED BY '$(sql_quote "$DB_ADMIN_PASSWORD")';"
    # Start from a clean slate so re-runs remove anything granted by hand or by older versions.
    echo "REVOKE ALL PRIVILEGES, GRANT OPTION FROM $ACCOUNT;"
    echo "GRANT $GLOBAL_PRIVS ON *.* TO $ACCOUNT;"
    for db in $DB_ADMIN_DATABASES; do
        echo "GRANT $DB_PRIVS ON \`$db\`.* TO $ACCOUNT;"
    done
} | db_root

log "Database admin user $DB_ADMIN_USER@$DB_ADMIN_HOST is configured for: $DB_ADMIN_DATABASES"
echo "SHOW GRANTS FOR $ACCOUNT;" | db_root | sed 's/IDENTIFIED BY PASSWORD .*//'
log "Credentials are stored in $ENV_FILE as DB_ADMIN_USER / DB_ADMIN_PASSWORD."
