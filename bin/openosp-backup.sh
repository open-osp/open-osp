#!/bin/bash
# DO NOT execute this script during production hours.

# only set debug logging when absolutely needed. otherwise use the minimal log entries
# set -x

#Global functions
# log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
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

# Global variables
site=$(pwd | grep -oh "[^/]*$")
filename=$site.$(date +%Y%m%d-%H%M%S)
folder=$(date +%Y%m)
clinicname="openosp-$site"

# if an HDC argument, then dump the HDC export and then exit the script
if [[ $* == *--hdc* ]]; then

    log "Executing HDC export for: $site"

    # check for AWS connection
    validate_aws

    docker compose exec -T db mysqldump -uroot -p"${MYSQL_PASSWORD}" --skip-triggers oscar \
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
    provider > hdc-$filename.sql
    rm -f hdc-$filename.sql.gpg

    # encrypt
    # always trust the key, it's verified manually.
    gpg --output hdc-$filename.sql.gpg --encrypt --trust-model always --recipient pki-prod@hdcbc.ca hdc-$filename.sql
    #rm hdc-$filename

    aws s3 cp hdc-$filename.sql.gpg s3://openosp-hdc-transit/$clinicname/$folder/hdc-$filename.sql.gpg
    rm hdc-$filename.sql.gpg hdc-$filename.sql

    if [ $? -eq 0 ]; then
      lg "HDC export for $site completed"
    else
      log "ERROR: HDC export for $site failed. Enable debug log for more information"
    fi

    # Exit the script immediately
    exit 0
fi

# start up Expedius again on any exit of this script.
trap 'docker compose restart oscar; docker compose start expedius' EXIT

# stop Expedius to avoid connection timeouts with OSCAR during the backup process.
docker compose stop expedius

# prepare file path for database dump
if [ -z "$BACKUP_BUCKET" ]
then
    BACKUP_BUCKET=backups
    log "WARN: BACKUP_BUCKET env var not specified, defaulting to the 'backups' bucket."
fi

if [ -z "$BACKUP_CMD" ]
then
    BACKUP_CMD="mysqldump -u root -p${MYSQL_ROOT_PASSWORD} oscar"
    log "WARN: BACKUP_CMD env var not specified, executing default backup command."
fi

if [ -z "$DUMP_LOCATION" ]
then
    DUMP_LOCATION='./dump'
    log "ERROR: DUMP location not specified, using $DUMP_LOCATION"
fi

mkdir -p "$DUMP_LOCATION"

# dump database backup and then push to Amazon S3 storage.
if [[ $* == *--s3* ]]; then

    # no AWS account. No go.
    validate_aws

    log "Exporting to Amazon S3"
    docker compose exec -T db "$BACKUP_CMD" | gzip > "$DUMP_LOCATION/db.sql.gz"

    # validate gzip file
    if gzip -t "$DUMP_LOCATION/db.sql.gz" >/dev/null 2>&1; then
        log "Gzip successful."
    else
        log "ERROR: Gzip failed. Exiting."
        exit 1
    fi

    # Remove double quotes, user might input value enclosed in "" in local.env
    BACKUP_BUCKET="${BACKUP_BUCKET//\"}"
    $aws s3 sync /open-osp/volumes s3://$BACKUP_BUCKET/$clinicname/volumes --storage-class STANDARD_IA --exclude ".sync/*"
    $aws s3 mv /open-osp/$DUMP_LOCATION/db.sql.gz s3://$BACKUP_BUCKET/$clinicname/$folder/$filename.sql.gz

    if [ $? -eq 0 ]; then
      log "Amazon S3 export successful"
    else
        log "ERROR: S3 upload failed. Check the AWS CLI configuration and try again."
        exit 1
    fi
fi

# dump database and then store locally at the given location
if [[ $* == *--efs* ]]; then
    docker compose exec -T db "$BACKUP_CMD" | gzip > "$DUMP_LOCATION/db.sql.gz"

    log "Executing backup to local file storage"
    # validate gzip file
    if gzip -t "$DUMP_LOCATION/db.sql.gz" >/dev/null 2>&1; then
        log "Gzip successful."
    else
        log "ERROR: Gzip failed. Exiting."
        exit 1
    fi

    mkdir -p /srv/efs/$clinicname/volumes
    mkdir -p /srv/efs/$clinicname/$folder/
    rsync -av ./volumes/ /srv/efs/$clinicname/volumes/
    mv $DUMP_LOCATION/db.sql.gz /srv/efs/$clinicname/$folder/$filename.sql.gz
fi

# dump the database LOG table, compress, then store locally for archive, and then truncate table.
if [[ $* == *--archive-logs* ]]; then

    log "Archiving database logs"
    ARCHIVE_NAME=log_archive_$(date +"%d-%m-%y").sql
    docker compose exec -T db mysqldump -uroot -p${MYSQL_ROOT_PASSWORD} oscar log > $ARCHIVE_NAME
    mv $ARCHIVE_NAME volumes/OscarDocument/oscar/
    docker compose exec -T db mysql -uroot -p${MYSQL_ROOT_PASSWORD} oscar < bin/archive-logs.sql
fi

log "backup complete"
