#!/bin/bash

#TODO: add a warning

#TODO: add a warning

set -euxo

read -p "Are you sure you want to wipe the DB and all local config? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

  rm -f *.war.*
  rm -f *.war

  docker-compose down

  docker-compose -f docker-compose.admin.yml run builder rm -fr oscar

  dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")

  docker volume rm ${dcid}_mariadb-files &> /dev/null

  rm oscar.properties
  rm drugref2.properties
  rm docker-compose.override.yml
fi

