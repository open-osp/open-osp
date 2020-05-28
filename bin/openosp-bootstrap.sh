#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10

docker-compose -f docker-compose.build.yml run builder ./bin/clone.sh
docker-compose exec db ./bin/populate-db.sh

