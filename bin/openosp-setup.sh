#!/bin/bash

set -euxo

DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

#TODO: use this db password in the instance

if [ ! -f local.env ]; then
  echo "copying oscar properties template"
  cp ./local.env.template ./local.env

  echo "Removing existing DB passwords"
  sed '/MYSQL_ROOT_PASSWORD/d' ./local.env
  sed '/MYSQL_PASSWORD/d' ./local.env

  echo "Generating new DB passwords"
  echo "MYSQL_ROOT_PASSWORD=${DB_PASSWORD}" >> ./local.env
  echo "MYSQL_PASSWORD=${DB_PASSWORD}" >> ./local.env
fi

# if this is a fresh install
if [ ! -f ./volumes/oscar.properties ]; then
  echo "copying oscar properties template"
  cp docker/tomcat_oscar/conf/templates/oscar_mcmaster_bc.properties ./volumes/oscar.properties
fi

#if [ ! -f drugref.properties ]; then
#  echo "copying drugref2 properties template"
#  cp ./conf/drugref2.properties ./drugref2.properties
#fi

if [ ! -f docker-compose.override.yml ]; then
  echo "copying docker-compose dev template"
  cp dc.dev.yml docker-compose.override.yml
fi

echo "Cloning in order to bootstrap db."
docker-compose -f docker-compose.admin.yml run builder ./bin/clone.sh
./bin/setup.sh
./bin/run.sh

