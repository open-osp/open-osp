#!/bin/bash

set -e

if [ -z "$BACKUPS" ]
then
    echo 'Manual Backups, using local.env variables'
    source ./local.env
fi

if [ -z "$BACKUP_BUCKET" ]
then
    BACKUP_BUCKET=backups
    echo "BACKUP_BUCKET env var not specified, defaulting to the 'backups' bucket."
fi

if [ -z "$BACKUP_CMD" ]
then
    BACKUP_CMD='mysqldump -uroot -pliyi oscar --result-file=/dump/db.sql'
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

site=$(docker ps --format '{{.Names}}' | grep _db_ | cut -d'_' -f1) 
filename=$site.$(date +%Y%m%d-%H%M%S)
folder=$(date +%Y%m)
clinicname="openosp-${CLINIC_NAME//\"}"

rm -rf $DUMP_LOCATION
rm -f $DUMP_LOCATION.tar.lrz
rm -f $DUMP_LOCATION.tar

mkdir $DUMP_LOCATION

docker exec -t ${site}_db_1 rm -fr /dump
docker exec -t ${site}_db_1 mkdir /dump
docker exec -t ${site}_db_1 $BACKUP_CMD
docker cp ${site}_db_1:/dump/db.sql $DUMP_LOCATION/db.sql

if [ -z "$BACKUPS" ]
then
    echo 'Manual backups, using OscarDocument volume'
else
    echo 'Automated backups'
    docker cp ${site}_tomcat_oscar_1:/var/lib/OscarDocument ./OscarDocument
fi
docker cp ${site}_tomcat_oscar_1:/root/oscar.properties $DUMP_LOCATION/oscar.properties
docker cp ${site}_tomcat_oscar_1:/root/drugref2.properties $DUMP_LOCATION/drugref2.properties

tar cvf $DUMP_LOCATION.tar $DUMP_LOCATION
lrzip $DUMP_LOCATION.tar

echo "done backups"

# Remove double quotes, user might input value enclosed in "" in local.env
BACKUP_BUCKET="${BACKUP_BUCKET//\"}"
aws s3 sync ./OscarDocument s3://$BACKUP_BUCKET/$clinicname/OscarDocument --storage-class STANDARD_IA --exclude ".sync/*"
aws s3 mv $DUMP_LOCATION.tar.lrz s3://$BACKUP_BUCKET/$clinicname/$folder/$filename.tar.lrz