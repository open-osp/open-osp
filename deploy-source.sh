#!/bin/sh

set -euxo

echo "This script is a fork of "Oscar in a Box" by http://nuchange.ca"

echo "Destroy any old instance (keeping database)."
docker-compose down

export OSCAR_WAR=./oscar/target/oscar-14.0.0-SNAPSHOT.war

echo "Compiling OSCAR. This may take some time...."
docker-compose run builder ./bin/build.sh
echo "Setting up docker containers. This may take some time...."
docker-compose up -d db 
echo "Waiting for db containers initialize (1 min)"
docker-compose exec db ./bin/populate-db.sh
echo "Bringing up tomcat"
docker-compose up -d tomcat_oscar

echo "OSCAR is set up at http://localhost/oscar_mcmaster by default. You can change the port in docker-compose.override.yml"

