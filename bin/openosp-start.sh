#!/bin/bash

docker-compose stop oscar
docker-compose rm oscar

docker-compose stop expedius
docker-compose rm expedius

docker-compose stop flask_oscar
docker-compose rm flask_oscar

docker-compose up -d db
sleep 5

docker-compose up -d oscar
docker-compose up -d flask_oscar

docker-compose up -d expedius
