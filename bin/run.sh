#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10
echo "Bringing up tomcat"
docker-compose up -d tomcat_oscar

sleep 5
docker-compose up -d nginx

echo "OSCAR is set up at http://<this host>/oscar"

