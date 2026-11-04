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
    # mysqladmin ping exits 0 whenever the server is up, even if access is denied,
    # so no credentials are needed.
    if mysqladmin ping -h "${1:-db}" --silent >/dev/null 2>&1; then
        echo "OK      db (${1:-db})"
    else
        echo "FAILED  db (${1:-db}) is not accepting connections"
        exit 1
    fi
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
