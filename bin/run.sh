#!/bin/bash

echo "Setting up database..."
docker compose  up -d db
sleep 10

echo "Starting FaxWS..."
docker compose  up -d faxws

echo "Expediting Expedius..."
docker compose  up -d expedius

echo "Bringing up Oscar..."
docker compose  up -d oscar

echo "OSCAR is set up at http://<this host>/oscar"
