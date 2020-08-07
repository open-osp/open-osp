#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10

docker-compose -f docker-compose.build.yml run -T builder ./bin/clone.sh
docker-compose exec -T db ./bin/populate-db.sh
./bin/setup-faxws.sh

