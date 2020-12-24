#!/bin/bash

set -x

if [ -z "$BACKUP_BUCKET" ]
then
    BACKUP_BUCKET=backups
    echo "BACKUP_BUCKET env var not specified, defaulting to the 'backups' bucket."
fi

if [ -z "$BACKUP_CMD" ]
then
    BACKUP_CMD="mysqldump -uroot -p${MYSQL_ROOT_PASSWORD} oscar"
    echo "BACKUP_CMD env var not specified, defaulting to '${BACKUP_CMD}'."
fi

if [ -e $HOME/.aws/credentials ]
then
    echo "aws credentials found."
else
    echo "no ~/.aws/credentials file found. please mount one for me."
    exit 1
fi

if [ -z "$DUMP_LOCATION" ]
then
    DUMP_LOCATION='./dump'
    echo "DUMP location not specified, using $DUMP_LOCATION"
fi

site=$(pwd | grep -oh "[^/]*$")
filename=$site.$(date +%Y%m%d-%H%M%S)
folder=$(date +%Y%m)

mkdir -p $DUMP_LOCATION

docker exec -t ${site}_db_1 $BACKUP_CMD | gzip > $DUMP_LOCATION/db.sql.gz

clinicname="openosp-$site"
echo "done backups"

aws="docker run --rm -t -v $HOME/.aws:/root/.aws -v $(pwd):/open-osp amazon/aws-cli"

if [[ $* == *--s3* ]]; then
    # Remove double quotes, user might input value enclosed in "" in local.env
    BACKUP_BUCKET="${BACKUP_BUCKET//\"}"
    $aws s3 sync /open-osp/volumes s3://$BACKUP_BUCKET/$clinicname/volumes --storage-class STANDARD_IA --exclude ".sync/*"
    $aws s3 mv /open-osp/$DUMP_LOCATION/db.sql.gz s3://$BACKUP_BUCKET/$clinicname/$folder/$filename.sql.gz
fi

if [[ $* == *--efs* ]]; then
    mkdir -p /srv/efs/$clinicname/volumes
    mkdir -p /srv/efs/$clinicname/$folder/
    rsync -av ./volumes/ /srv/efs/$clinicname/volumes/
    mv $DUMP_LOCATION/db.sql.gz /srv/efs/$clinicname/$folder/$filename.sql.gz

fi

if [[ $* == *--hdc* ]]; then
    docker-compose exec db mysqldump -uoscar -p${MYSQL_PASSWORD} oscar \
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
    gpg --output hdc-$filename.sql.gpg --encrypt --trust-model always --recipient pki-dev@hdcbc.ca hdc-$filename.sql
    #rm hdc-$filename
    
    aws s3 cp hdc-$filename.sql.gpg s3://openosp-hdc-transit/$clinicname/$folder/hdc-$filename.sql.gpg
fi

docker-compose restart oscar


