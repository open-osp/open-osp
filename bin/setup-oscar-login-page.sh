#!/bin/bash

source ./local.env

## set the login page elements
mkdir -p ./volumes/OscarDocument/login
 
# Logo for the OSP
# TODO: these should use templates included in the repo.
if [ -f ./supportLogo.png ]; then
  cp ./supportLogo.png ./volumes/OscarDocument/login/supportLogo.png
fi

# Logo for the user clinic
# TODO: these should use templates included in the repo.
if [ -f ./clinicLogo.png ]; then
  cp ./supportLogo.png ./volumes/OscarDocument/login/clinicLogo.png
fi

# Template for the AUA
cp docker/oscar/conf/templates/AcceptableUseAgreement.txt ./volumes/OscarDocument/login/AcceptableUseAgreement.txt

# Address and Link settings from the local.env file.
sed -e "s|supportLink=.*|supportLink=${SUPPORT_LINK//&/\\&}|g" -e "s|supportText=.*|supportText=${SUPPORT_TEXT//&/\\&}|g" -e "s|supportName=.*|supportName=${SUPPORT_NAME//&/\\&}|g" -e "s|clinicLink=.*|clinicLink=${CLINIC_LINK//&/\\&}|g" -e "s\clinicText=.*\clinicText=${CLINIC_TEXT//&/\\&}\g" -e "s|clinicName=.*|clinicName=${CLINIC_NAME//&/\\&}|g" -e "s|tabName=.*|tabName=${TAB_NAME//&/\\&}|g" docker/oscar/conf/templates/login_page_template.txt > login_page_template.txt.tmp  
mv ./login_page_template.txt.tmp ./volumes/OscarDocument/login/.env
