#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10
echo "Waiting for db containers to initialize (1 min)"
docker-compose exec db ./bin/populate-db.sh
sleep 10
echo "Bringing up tomcat"
docker pull openosp/open-osp
docker-compose up -d tomcat_oscar
docker-compose up -d nginx

echo "OSCAR is set up at http://localhost/oscar_mcmaster"
echo "OpenOSP started as a fork of "Oscar in a Box" by http://nuchange.ca"

