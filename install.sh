#!/bin/sh

set -euxo

echo "Destroy any old instance."
docker-compose down

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone --depth 1 https://bitbucket.org/oscaremr/oscar.git
fi

echo "Compiling OSCAR. This may take some time...."
docker-compose run builder
echo "Setting up docker containers. This may take some time...."
docker-compose up -d db
echo "Waiting for db containers initialize (1 min)"
sleep 20
docker-compose exec db sh -c "cd /code/ && ./populate-db.sh"
echo "Bringing up tomcat"
docker-compose up -d tomcat_oscar

echo "OSCAR is set up at http://localhost:8091/oscar_mcmaster"
echo "This script is a fork of "Oscar in a Box" by http://nuchange.ca"

