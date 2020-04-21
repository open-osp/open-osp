#!/bin/bash

# uncomment for debugging
#set -euxo
set -eu

# tr command does not work in UNIX environments. OpenSSL is common in every environment.
DB_PASSWORD=$(openssl rand -base64 8)
EXPEDIUS_SECRET=$(openssl rand -base64 8)

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
  
  echo "Setting up landing page"
  read -p "Clinic name: " CLINIC_NAME
  echo "## Name or title of the clinic" >> ./local.env
  echo "CLINIC_NAME=\"${CLINIC_NAME}\"" >> ./local.env

  read -p "Clinic sub text (address, phone): " CLINIC_TEXT
  echo "## clinic subtext such as address phone etc." >> ./local.env
  echo "CLINIC_TEXT=\"${CLINIC_TEXT}\"" >> ./local.env
  
  read -p "Clinic website link, including HTTP(S): " CLINIC_LINK
  echo "## clinic HTML link to a clinic website if one is supplied." >> ./local.env
  echo "CLINIC_LINK=\"${CLINIC_LINK}\"" >> ./local.env

  read -p "Title name in browser tabs (default: OSCAR EMR): " TAB_NAME
  echo "## Title name in browser tabs (default: OSCAR EMR)" >> ./local.env
  if [ ${TAB_NAME} = "" ];
    then
    	echo "TAB_NAME=\"OSCAR EMR\"" >> ./local.env
	else
		echo "TAB_NAME=\"${TAB_NAME}\"" >> ./local.env
  fi
 
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

