#!/bin/bash

if [ -z "$CRON_SCHEDULE" ]
then
    CRON_SCHEDULE="midnight"
    echo "0  0  *  *  *    /backups.sh" > /etc/crontabs/root
else
    CRON_SCHEDULE="${CRON_SCHEDULE//\"}"
    echo "$CRON_SCHEDULE   /backups.sh" > /etc/crontabs/root
fi

echo "Creating a backup job that will run every $CRON_SCHEDULE"

crond -f