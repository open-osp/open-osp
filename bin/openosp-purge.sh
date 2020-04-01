#!/bin/bash


set -euo

read -p "Are you sure you want to wipe the DB and all local config? [ Type CONFIRM to delete then ENTER ]:" -n 8 -r -e
echo    # (optional) move to a new line
if [[ $REPLY =~ "CONFIRM" ]]
then

  # Docker commands reference this file so it must exist for now. Delete it later.
  touch local.env

  echo "Removing OSCAR files..."
  rm -f *.war.*
  rm -f *.war

  echo "Removing volumes"
  rm -fr volumes/*

  echo "Removing local files (Docker settings, Environment variables)"
  rm -fr ./docker-compose.override.yml
  docker-compose -f docker-compose.admin.yml run builder rm -fr oscar
  docker-compose down -v
  rm -f local.env

  #dcid=$(pwd | grep -oh "[^/]*$" | sed "s/[^a-z\d_\-]//g")
  #docker volume rm ${dcid}_mariadb-files &> /dev/null

  echo "Done"
else
  echo "Not confirmed"
fi

