#!/bin/bash

if [ -f "./local.env" ]
then
    source ./local.env
fi

echo "Setting up database..."
docker compose up -d db
sleep 10

docker compose -f docker-compose.build.yml run --rm builder ./bin/clone.sh ${OSCAR_REPO:-""} ${OSCAR_TREEISH:-""}
docker compose exec db ./bin/populate-db.sh ${LOCATION:-""}

./bin/setup-faxws.sh

