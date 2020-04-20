#!/bin/bash

# uncomment for debugging
#set -euxo
set -eu

DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
EXPEDIUS_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

if [ ! -f local.env ]; then
  echo "copying ENV template"
  cp ./local.env.template ./local.env

  echo "Generating new DB passwords"
  echo "MYSQL_ROOT_PASSWORD=${DB_PASSWORD}" >> ./local.env
  echo "MYSQL_PASSWORD=${DB_PASSWORD}" >> ./local.env

  echo "Generating expedius secrets"
  echo "CACERTS_PASSWORD=${EXPEDIUS_SECRET}" >> ./local.env
  echo "STORE_PASS=${EXPEDIUS_SECRET}" >> ./local.env
  echo "EXPEDIUS_PASSWORD=${EXPEDIUS_SECRET}" >> ./local.env

  read -p "Enter clinic text (address, phone): " CLINIC_TEXT
  echo "## clinic subtext such as address phone etc." >> ./local.env
  echo "CLINIC_TEXT=${CLINIC_TEXT}" >> ./local.env
  
  read -p "Enter clinic website link, including HTTP(S): " CLINIC_LINK
  echo "## clinic HTML link to a clinic website if one is supplied." >> ./local.env
  echo "CLINIC_LINK=${CLINIC_LINK}" >> ./local.env

  read -p "Name of the clinic: " CLINIC_NAME
  echo "## Name or title of the clinic" >> ./local.env
  echo "CLINIC_NAME=${CLINIC_NAME}" >> ./local.env

else
  echo "local.env exists, not configuring."
fi

# if this is a fresh install
if [ ! -f ./volumes/oscar.properties ]; then
  echo "copying oscar properties template"
  cp docker/oscar/conf/templates/oscar_mcmaster_bc.properties ./volumes/oscar.properties

  echo "Using generated password in Oscar properties file"
  sed '/db_password/d' ./volumes/oscar.properties
  echo "db_password=${DB_PASSWORD}" >> ./volumes/oscar.properties

fi

if [ ! -f ./volumes/drugref2.properties ]; then
  echo "copying drugref properties template"
  cp docker/oscar/conf/templates/drugref2.properties ./volumes/drugref2.properties

  echo "Using generated password in Drugref properties file"
  echo "db_password=${DB_PASSWORD}" >> ./volumes/drugref2.properties
fi

if [ ! -f docker-compose.override.yml ]; then
  echo "copying docker-compose dev template"
  cp dc.dev.yml docker-compose.override.yml
fi

echo "Cloning in order to bootstrap db."
./bin/setup-expedius.sh
./bin/setup-keys.sh
./bin/setup-oscar-login-page.sh

