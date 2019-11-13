#!/bin/sh

set -euxo

docker-compose down

sudo rm -fr oscar

dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")

docker volume rm ${dcid}_mariadb-files

