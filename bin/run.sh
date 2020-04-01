#!/bin/bash

echo "Setting up database..."
docker-compose up -d db
sleep 10

echo "Bringing up tomcat"
docker-compose up -d oscar

echo "expediting Expedius"
docker-compose up -d expedius

echo "OSCAR is set up at http://<this host>/oscar"

