#!/bin/bash

echo "Starting OpenOSP services."

docker-compose stop oscar
docker-compose rm -f oscar

docker-compose stop expedius
docker-compose rm -f expedius

docker-compose up -d db
sleep 5

docker-compose up -d oscar

docker-compose up -d expedius
