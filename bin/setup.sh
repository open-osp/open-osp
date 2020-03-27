#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10

echo "Generating self-signed cert for temporary use. Please replace with a CA signed one."
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=${HOST:-openosp.ca}" -keyout ./volumes/ssl.key -out ./volumes/ssl.crt
echo "Waiting for db containers to initialize"
docker-compose exec db ./bin/populate-db.sh

#if [ ! -f ./conf/ssl.key ] || [ ! -f ./conf/ssl.crt ] ; then 
#    echo "Generating self-signed cert for temporary use. Please replace with a CA signed one."
#    
#    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=${HOST:-openosp.ca}" -keyout ./conf/ssl.key -out ./conf/ssl.crt
#fi
