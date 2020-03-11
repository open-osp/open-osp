#!/bin/bash

set -euxo

DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

#TODO: use this db password in the instance

# if this is a fresh install
if [ ! -f oscar.properties ]; then
  echo "copying oscar properties template"
  cp ./conf/templates/oscar_mcmaster_bc.properties ./oscar.properties
fi

if [ ! -f drugref.properties ]; then
  echo "copying drugref2 properties template"
  cp ./conf/drugref2.properties ./drugref2.properties
fi

if [ ! -f docker-compose.override.yml ]; then
  echo "copying docker-compose dev template"
  cp dc.dev.yml docker-compose.override.yml
fi

#if [[ $* == *--bootstrap* ]]; then
  docker-compose -f docker-compose.admin.yml run builder ./bin/clone.sh
  ./bin/setup.sh
#fi

./bin/run.sh

