#!/bin/bash

# --build: make sure the health image has the current Dockerfile (e.g. mariadb-client).
docker compose -f docker-compose.admin.yml run --build --rm -t health
