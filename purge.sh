#!/bin/sh

set -euxo

rm -f *.war.*
rm -f *.war

docker-compose down

docker-compose run builder rm -fr oscar

dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")

docker volume rm ${dcid}_mariadb-files &> /dev/null

