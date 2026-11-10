#!/bin/bash
# DO NOT execute this script during production hours.

# Stop on any unhandled error, on unset variables, and when any command in a pipeline fails
# (without pipefail a failed mysqldump piped into gzip would go unnoticed).
set -Eeuo pipefail

# only set debug logging when absolutely needed. otherwise use the minimal log entries
# set -x

#Global functions
# log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# report where an unhandled error stopped the script.
trap 'log "ERROR: command failed with exit code $? at line $LINENO: $BASH_COMMAND"' ERR

# record a failed step without stopping, so the remaining backup steps still run.
# the script exits non-zero at the end if any step failed.
failures=0
fail() {
    log "ERROR: $1"
    failures=$((failures + 1))
}

# ping a monitoring URL (healthchecks.io style) so that failed or missing backups raise an alert.
# $1 = URL (may be empty, then nothing is sent), $2 = success|fail
notify() {
    local url=$1
    [ -n "$url" ] || return 0
    if ! command -v curl >/dev/null 2>&1; then
        log "WARN: curl not installed, cannot send the backup status to the healthcheck URL."
        return 0
    fi
    [ "$2" = fail ] && url="${url%/}/fail"
    curl -fsS -m 10 --retry 3 -o /dev/null "$url" || log "WARN: could not reach the healthcheck URL."
}

# check if an AWS account has been set up on this server.
validate_aws() {
    if [ -e "$HOME/.aws/credentials" ]
    then
        log "aws credentials found."
        aws="docker run --rm -t -v $HOME/.aws:/root/.aws -v $(pwd):/open-osp amazon/aws-cli"
    else
        log "ERROR: no ~/.aws/credentials file found. please mount one for me."
        exit 1
    fi
}

# Run a MySQL client program (mysqldump, mysql) inside the db container as the given database user:
#   db_exec <user> <program> [args...]
# The password is read from the db container's own environment, which is loaded from local.env:
# MYSQL_ROOT_PASSWORD for root, BACKUP_DB_PASSWORD for any other user. It is handed to the client
# through MYSQL_PWD, so it never appears on a command line on the host or in the container.
db_exec() {
    local user=$1
    shift
    # shellcheck disable=SC2016 # expanded by the shell inside the db container, not here.
    docker compose exec -T -e DB_USER="$user" db sh -c '
        if [ "$DB_USER" = root ]; then
            MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}"
        else
            MYSQL_PWD="${BACKUP_DB_PASSWORD:-}"
        fi
        if [ -z "$MYSQL_PWD" ]; then
            echo "ERROR: no password for database user $DB_USER in the db container environment." \
                 "Set it in local.env, then recreate the db container: docker compose up -d db" >&2
            exit 1
        fi
        export MYSQL_PWD
        program=$1
        shift
        exec "$program" -u"$DB_USER" "$@"
    ' db_exec "$@"
}

# Dump options for the main database backup.
# --single-transaction takes a consistent snapshot of InnoDB tables without locking them, so OSCAR
# can keep writing during the dump. --quick streams rows instead of buffering whole tables in memory.
# --no-tablespaces avoids needing the PROCESS privilege for a dedicated backup user.
DUMP_OPTS=(--single-transaction --quick --no-tablespaces --routines --events --triggers)

# write the full oscar database dump to stdout.
dump_db() {
    if [ -n "${BACKUP_CMD:-}" ]; then
        # legacy custom command, run through a shell so that it is split into words properly.
        docker compose exec -T db sh -c "$BACKUP_CMD"
    else
        db_exec "$db_user" mysqldump "${DUMP_OPTS[@]}" oscar
    fi
}

# check that a dump file is complete: <file> <minimum size in bytes>
# a .gz file must pass the gzip integrity test. In every case the dump must end with the
# "-- Dump completed" line that mysqldump writes only when it finishes successfully.
verify_dump() {
    local file=$1 min_bytes=$2 size reader=cat
    if [ ! -f "$file" ]; then
        log "ERROR: dump file $file not found."
        return 1
    fi
    size=$(wc -c < "$file")
    size=$((size))
    if [ "$size" -lt "$min_bytes" ]; then
        log "ERROR: dump file $file is only $size bytes (minimum $min_bytes). The dump probably failed."
        return 1
    fi
    if [[ $file == *.gz ]]; then
        if ! gzip -t "$file" >/dev/null 2>&1; then
            log "ERROR: dump file $file is not a valid gzip archive."
            return 1
        fi
        reader="gzip -dc"
    fi
    if ! $reader "$file" | tail -n 1 | grep -q '^-- Dump completed'; then
        log "ERROR: dump file $file does not end with '-- Dump completed'. The dump is incomplete."
        return 1
    fi
    log "Verified $file ($size bytes)."
}

# dump the database to $DUMP_LOCATION/db.sql.gz and verify it. Exits the script if it fails.
dump_and_verify_db() {
    if ! dump_db | gzip > "$DUMP_LOCATION/db.sql.gz"; then
        log "ERROR: database dump failed. Exiting."
        exit 1
    fi
    if ! verify_dump "$DUMP_LOCATION/db.sql.gz" "$min_bytes"; then
        log "ERROR: database dump verification failed. Exiting."
        exit 1
    fi
}

# runs on every exit of this script: restarts the services that were stopped for the backup,
# reports the overall result, and pings the healthcheck URL.
services_stopped=0
mode_label="backup"
healthcheck_url=""
on_exit() {
    local rc=$?
    trap - EXIT ERR
    set +e
    if [ "$services_stopped" = 1 ]; then
        docker compose restart oscar || { log "ERROR: could not restart oscar."; rc=1; }
        docker compose start expedius || { log "ERROR: could not start expedius."; rc=1; }
    fi
    if [ "$rc" -eq 0 ] && [ "$failures" -gt 0 ]; then
        rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        log "$mode_label complete"
        notify "$healthcheck_url" success
    else
        log "ERROR: $mode_label for $site failed (exit code $rc). Enable debug log for more information."
        notify "$healthcheck_url" fail
    fi
    exit "$rc"
}
trap on_exit EXIT

# Global variables
site=$(pwd | grep -oh "[^/]*$")
filename=$site.$(date +%Y%m%d-%H%M%S)
folder=$(date +%Y%m)
clinicname="openosp-$site"

# database user for dumps. Defaults to root; set BACKUP_DB_USER and BACKUP_DB_PASSWORD in local.env
# to use a dedicated read-only backup user (see doc/backup-process.md).
db_user="${BACKUP_DB_USER:-root}"

# smallest dump file size (bytes) accepted as a successful backup.
min_bytes="${BACKUP_MIN_BYTES:-10240}"

# if an HDC argument, then dump the HDC export and then exit the script
if [[ $* == *--hdc* ]]; then

    mode_label="HDC export"
    healthcheck_url="${HDC_HEALTHCHECK_URL:-}"
    log "Executing HDC export for: $site"

    # check for AWS connection
    validate_aws

    hdc_file="hdc-$filename.sql"
    if ! db_exec "$db_user" mysqldump --single-transaction --quick --no-tablespaces --skip-triggers oscar \
    allergies \
    appointment \
    appointmentType \
    billing \
    billing_history \
    billingmaster \
    billingservice \
    billingstatus_types \
    casemgmt_note \
    clinic \
    demographic \
    demographicArchive \
    demographicExt \
    demographicExtArchive \
    diagnosticcode \
    drugReason \
    drugs \
    dxresearch \
    LookupListItem \
    measurements \
    measurementsExt \
    measurementType \
    prescription \
    preventions \
    preventionsExt \
    provider > "$hdc_file"; then
        rm -f "$hdc_file"
        log "ERROR: HDC database dump failed."
        exit 1
    fi
    if ! verify_dump "$hdc_file" "$min_bytes"; then
        rm -f "$hdc_file"
        exit 1
    fi
    rm -f "$hdc_file".gpg

    log "Encrypt HDC export"
    # always trust the key, it's verified manually.
    if ! gpg --output "$hdc_file".gpg --encrypt --trust-model always --recipient pki-prod@hdcbc.ca "$hdc_file"; then
        rm -f "$hdc_file" "$hdc_file".gpg
        log "ERROR: HDC export encryption failed."
        exit 1
    fi
    # the plain-text export is no longer needed once it is encrypted.
    rm -f "$hdc_file"

    log "copy to S3: $hdc_file.gpg s3://openosp-hdc-transit/$clinicname/$folder/$hdc_file.gpg"
    if aws s3 cp --quiet "$hdc_file".gpg s3://openosp-hdc-transit/"$clinicname"/"$folder"/"$hdc_file".gpg; then
        rm -f "$hdc_file".gpg
    else
        log "ERROR: HDC upload to S3 failed. The encrypted export was kept for a retry: $(pwd)/$hdc_file.gpg"
        exit 1
    fi

    # Exit the script immediately
    exit 0
fi

# stop Expedius to avoid connection timeouts with OSCAR during the backup process.
# OSCAR is restarted and Expedius started again on any exit of this script (see on_exit).
healthcheck_url="${BACKUP_HEALTHCHECK_URL:-}"
services_stopped=1
docker compose stop expedius

# prepare file path for database dump
if [ -z "${BACKUP_BUCKET:-}" ]
then
    BACKUP_BUCKET=backups
    log "WARN: BACKUP_BUCKET env var not specified, defaulting to the 'backups' bucket."
fi

if [ -n "${BACKUP_CMD:-}" ]
then
    log "WARN: using the custom BACKUP_CMD. Its output must end with mysqldump's '-- Dump completed' line."
else
    log "Dumping the database as user '$db_user' with: mysqldump ${DUMP_OPTS[*]} oscar"
fi

if [ -z "${DUMP_LOCATION:-}" ]
then
    DUMP_LOCATION='./dump'
    log "WARN: DUMP location not specified, using $DUMP_LOCATION"
fi

mkdir -p "$DUMP_LOCATION"

# dump database backup and then push to Amazon S3 storage.
if [[ $* == *--s3* ]]; then

    # no AWS account. No go.
    validate_aws

    log "Exporting to Amazon S3"
    dump_and_verify_db

    # Remove double quotes, user might input value enclosed in "" in local.env
    BACKUP_BUCKET="${BACKUP_BUCKET//\"}"

    # upload the database first: it is the most important part of the backup.
    rc=0
    # shellcheck disable=SC2086
    $aws s3 mv --quiet /open-osp/"$DUMP_LOCATION"/db.sql.gz s3://"$BACKUP_BUCKET"/"$clinicname"/"$folder"/"$filename".sql.gz || rc=$?
    if [ "$rc" -eq 0 ]; then
        log "Database uploaded to s3://$BACKUP_BUCKET/$clinicname/$folder/$filename.sql.gz"
    else
        fail "database upload to S3 failed (exit code $rc). Check the AWS CLI configuration and try again."
    fi

    rc=0
    # shellcheck disable=SC2086
    $aws s3 sync --quiet /open-osp/volumes s3://"$BACKUP_BUCKET"/"$clinicname"/volumes --storage-class STANDARD_IA --exclude ".sync/*" || rc=$?
    if [ "$rc" -eq 0 ]; then
        log "Volumes synced to s3://$BACKUP_BUCKET/$clinicname/volumes"
    elif [ "$rc" -eq 2 ]; then
        fail "volumes sync to S3 skipped some files (exit code 2). The document backup is incomplete."
    else
        fail "volumes sync to S3 failed (exit code $rc). Check the AWS CLI configuration and try again."
    fi

    if [ "$failures" -eq 0 ]; then
        log "Amazon S3 export successful"
    fi
fi

# dump database and then store locally at the given location
if [[ $* == *--efs* ]]; then

    # BACKUP_EFS_ROOT must be a mounted file system, otherwise the backup would silently fill
    # the local disk. Set BACKUP_EFS_REQUIRE_MOUNT=0 to allow a plain local directory.
    efs_root="${BACKUP_EFS_ROOT:-/srv/efs}"
    if [ "${BACKUP_EFS_REQUIRE_MOUNT:-1}" != 0 ] && ! mountpoint -q "$efs_root"; then
        log "ERROR: $efs_root is not a mounted file system. Exiting."
        exit 1
    fi

    log "Executing backup to local file storage"
    dump_and_verify_db

    mkdir -p "$efs_root"/"$clinicname"/volumes
    mkdir -p "$efs_root"/"$clinicname"/"$folder"/

    log "Moving database archive from $DUMP_LOCATION/db.sql.gz to $efs_root/$clinicname/$folder/$filename.sql.gz"
    if ! mv "$DUMP_LOCATION"/db.sql.gz "$efs_root"/"$clinicname"/"$folder"/"$filename".sql.gz; then
        fail "could not move the database archive to $efs_root/$clinicname/$folder/"
    fi

    log "Copy volumes from ./volumes/ to $efs_root/$clinicname/volumes/"
    rc=0
    rsync -a ./volumes/ "$efs_root"/"$clinicname"/volumes/ || rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "copying volumes to $efs_root/$clinicname/volumes/ failed (rsync exit code $rc)."
    fi
fi

# dump the database LOG table, compress, then store locally for archive, and then truncate table.
if [[ $* == *--archive-logs* ]]; then

    log "Archiving database logs"
    ARCHIVE_NAME=log_archive_$(date +"%d-%m-%y").sql
    if ! db_exec "$db_user" mysqldump --single-transaction --quick --no-tablespaces oscar log > "$ARCHIVE_NAME" \
        || ! verify_dump "$ARCHIVE_NAME" 0; then
        # never delete audit log rows that have not been archived.
        rm -f "$ARCHIVE_NAME"
        fail "log table export failed. Old log rows were NOT deleted."
    else
        log "Moving log archive $ARCHIVE_NAME to volumes/OscarDocument/oscar/"
        mv "$ARCHIVE_NAME" volumes/OscarDocument/oscar/
        # deleting rows needs write access, so this always runs as root.
        db_exec root mysql oscar < bin/archive-logs.sql
    fi
fi
