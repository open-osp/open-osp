#!/bin/bash

# uncomment for debugging
#set -euxo
set -eu

# tr command does not work in UNIX environments. OpenSSL is common in every environment.
DB_PASSWORD=$(openssl rand -base64 8)
EXPEDIUS_SECRET=$(openssl rand -base64 8)
FAXWS_SECRET=$(openssl rand -base64 8)

if [ ! -f local.env ]; then
  echo "copying ENV template"
  cp ./local.env.template ./local.env

  echo "Generating new DB passwords"
  echo "MYSQL_ROOT_PASSWORD=${DB_PASSWORD}" >> ./local.env
  echo "MYSQL_PASSWORD=${DB_PASSWORD}" >> ./local.env
  echo "FAXWS_TOMCAT_PASSWORD=${FAXWS_SECRET}" >> ./local.env

  echo "Generating expedius secrets"
  echo "CACERTS_PASSWORD=${EXPEDIUS_SECRET}" >> ./local.env
  echo "STORE_PASS=${EXPEDIUS_SECRET}" >> ./local.env
  echo "EXPEDIUS_PASSWORD=${EXPEDIUS_SECRET}" >> ./local.env
  
  echo "Setting up landing page"
  if [[ $* == *--noinput* ]]; then
    CLINIC_NAME=TEST
  else
    read -p "Clinic name: " CLINIC_NAME
  fi

  echo "## Name or title of the clinic" >> ./local.env
  echo "CLINIC_NAME=\"${CLINIC_NAME}\"" >> ./local.env
  if [[ $* == *--noinput* ]]; then
    CLINIC_TEXT=TEST
  else
    read -p "Clinic sub text (address, phone): " CLINIC_TEXT
  fi
  echo "## clinic subtext such as address phone etc." >> ./local.env
  echo "CLINIC_TEXT=\"${CLINIC_TEXT}\"" >> ./local.env

  if [[ $* == *--noinput* ]]
  then
    CLINIC_LINK=https://test.com
  else
    read -p "Clinic website link, including HTTP(S): " CLINIC_LINK
  fi

  echo "## clinic HTML link to a clinic website if one is supplied." >> ./local.env
  echo "CLINIC_LINK=\"${CLINIC_LINK}\"" >> ./local.env

  if [[ $* == *--noinput* ]]
  then
    TAB_NAME=TEST
  else
    read -p "Title name in browser tabs (default: OSCAR EMR): " TAB_NAME
  fi

  echo "## Title name in browser tabs (default: OSCAR EMR)" >> ./local.env
  if [ -z ${TAB_NAME} ];
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
  cp docker/oscar/conf/oscar_mcmaster_bc.properties ./volumes/oscar.properties

  echo "Using generated password in Oscar properties file"
  sed '/db_password/d' ./volumes/oscar.properties
  echo "db_password=${DB_PASSWORD}" >> ./volumes/oscar.properties

  sed '/db_username/d' ./volumes/oscar.properties
  echo "db_username=root" >> ./volumes/oscar.properties

fi

if [ ! -f ./volumes/drugref2.properties ]; then
  echo "copying drugref properties template"
  cp docker/oscar/conf/drugref2.properties ./volumes/drugref2.properties

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

if [ ! -d "./volumes/OscarDocument/oscar" ]; then
  echo "Creating dummy test billing file"
  mkdir ./volumes/OscarDocument/oscar
  mkdir ./volumes/OscarDocument/oscar/billing
  date > ./volumes/OscarDocument/oscar/billing/H_testfile
  date > ./volumes/OscarDocument/teleplanremit_testfile
fi

if [ ! -f "./volumes/OscarDocument/teleplanremit_testfile" ]; then
  date > ./volumes/OscarDocument/teleplanremit_testfile
fi

docker pull openosp/open-osp

