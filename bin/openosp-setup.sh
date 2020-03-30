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

  echo "Using generated password in Oscar properties file"
  sed '/db_password/d' ./volumes/oscar.properties
  echo "db_password=${DB_PASSWORD}" >> ./volumes/oscar.properties

if [ ! -f docker-compose.override.yml ]; then
  echo "copying docker-compose dev template"
  cp dc.dev.yml docker-compose.override.yml
fi

echo "Cloning in order to bootstrap db."
./bin/expedius-install.sh
./bin/setup.sh
./bin/setup_oscar_login_page.sh

