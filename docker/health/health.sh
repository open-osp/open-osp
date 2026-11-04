#!/bin/sh
#
# OpenOSP health checks.
#
# Usage: health.sh [service] [host]
#
#   service  db | oscar | faxws | expedius | all   (default: all)
#   host     host to probe (default: the compose service name)
#
# As a Docker Compose healthcheck this runs inside the target container,
# e.g. `health.sh oscar localhost`. From the admin `health` container
# (bin/openosp-health.sh) it runs with no arguments and checks every
# service in startup priority order: DB, Oscar, SRFax (faxws), Expedius.

set -eu

service="${1:-all}"
host="${2:-}"

# expect_http_code <expected> <url>
expect_http_code() {
    code=$(curl -s -o /dev/null -w "%{http_code}" -Ik --max-time 10 "$2" || true)
    if [ "$code" = "$1" ]; then
        echo "OK      $2 ($code)"
    else
        echo "FAILED  $2 (got $code, expected $1)"
        exit 1
    fi
}

check_db() {
    db_host="${1:-db}"
    # Newer images name the client mariadb-admin; older ones only ship mysqladmin.
    admin=$(command -v mariadb-admin || command -v mysqladmin || true)
    if [ -z "$admin" ]; then
        echo "FAILED  db ($db_host): mariadb-admin/mysqladmin not installed"
        exit 1
    fi

    # No credentials are used: any reply from the server, including an
    # authentication refusal, proves it is up and accepting connections.
    # --skip-ssl: MariaDB 11.x clients require SSL by default; the 10.5 server has none.
    if out=$("$admin" ping -h "$db_host" --skip-ssl --connect-timeout=5 2>&1); then
        echo "OK      db ($db_host)"
        return
    fi
    case "$out" in
        *"Access denied"*|*"is not allowed to connect"*)
            echo "OK      db ($db_host) (server responded: authentication refused)"
            ;;
        *)
            echo "FAILED  db ($db_host) is not accepting connections: $out"
            exit 1
            ;;
    esac
}

check_oscar() {
    expect_http_code 200 "https://${1:-oscar}/oscar/ops/health/heartbeat"
    expect_http_code 200 "https://${1:-oscar}/drugref2/"
}

check_faxws() {
    # 401: the web service is up and requires authentication.
    expect_http_code 401 "https://${1:-faxws}/faxWs"
}

check_expedius() {
    expect_http_code 200 "http://${1:-expedius}:8081/Expedius/"
}

case "$service" in
    db)       check_db "$host" ;;
    oscar)    check_oscar "$host" ;;
    faxws)    check_faxws "$host" ;;
    expedius) check_expedius "$host" ;;
    all)
        check_db
        check_oscar
        check_faxws
        check_expedius
        ;;
    *)
        echo "Unknown service: $service (expected db, oscar, faxws, expedius or all)"
        exit 2
        ;;
esac
