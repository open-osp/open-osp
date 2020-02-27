#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10
echo "Waiting for db containers to initialize (1 min)"
docker-compose exec db ./bin/populate-db.sh

echo "Generating self-signed cert for temporary use. Please replace with a CA signed one."
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=${HOST:-openosp.ca}" -keyout ./conf/ssl.key -out ./conf/ssl.crt

sleep 10
echo "Bringing up tomcat"
docker-compose up -d tomcat_oscar
docker-compose up -d nginx

echo "OSCAR is set up at http://localhost/oscar_mcmaster"
echo "OpenOSP started as a fork of "Oscar in a Box" by http://nuchange.ca"

