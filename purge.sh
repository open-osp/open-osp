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

  echo "Removing local files (Properties, Docker settings, Environment variables)"
  rm -f ./oscar.properties
  rm -f ./drugref2.properties
  rm -f ./docker-compose.override.yml
  if [ ! -f ./local.env ]; then
    echo "local.env file already removed..."
  else
    echo "Removing docker containers"
    docker-compose down -v

    docker-compose -f docker-compose.admin.yml run builder rm -fr oscar

    rm -f ./local.env
  fi


  dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")
  docker volume rm ${dcid}_mariadb-files &> /dev/null

  echo "Done"
else
  echo "Not confirmed"
fi

