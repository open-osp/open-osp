#!/bin/bash

#TODO: add a warning

#TODO: add a warning

set -euo

read -p "This will delete all your settings, database, and Oscar related files. [ Press ENTER for next line ]"
read -p "Are you sure you want to wipe the DB and all local config? [ Type CONFIRM to delete then ENTER ]:" -n 8 -r -e
echo    # (optional) move to a new line
if [[ $REPLY =~ "CONFIRM" ]]
then
  echo "Removing OSCAR files..."
  rm -f *.war.*
  rm -f *.war

  docker-compose down

  docker-compose -f docker-compose.admin.yml run builder rm -fr oscar

  dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")

  docker volume rm ${dcid}_mariadb-files &> /dev/null

  rm volumes/oscar.properties
  rm volumes/drugref2.properties
  rm docker-compose.override.yml
else
  echo "Not confirmed"
fi

