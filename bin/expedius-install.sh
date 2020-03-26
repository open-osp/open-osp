#!/bin/sh

##----------------------------------------------------------------------
## Expedius Install script
##
## Author: Dennis Warren @ Colcamex Resources
## Date: February 2012
## Updated: January 2020
## This script is used to install Expedius Lab Auto Downloader onto
## a server environment that supports Oscar EMR version 15*
##----------------------------------------------------------------------

# init variables
TOMCAT_PATH=\/usr\/local\/tomcat\/webapps
ADMIN_EMAIL=none
APP_DATA=\/var\/lib\/expedius
EMAIL_SERVICE=no
EXPEDIUS_USERNAME=admin
EXPEDIUS_PASSWORD=3xp3dius#1
OSCAR_USERNAME=expedius
OSCAR_PASSWORD=$(openssl rand -base64 8)
OSCAR_NUMBER=999995
OSCAR_PIN=1234
OSCAR_DN=tomcat_oscar:8080
OSCAR_CONTEXT=oscar
ADMIN_EMAIL=root@localhost.com


echo "Setting Expedius configuration properties"

# get administrators email address.
#echo "\nEnabling email service requires a smtp server, such as Postfix \nto be installed on this server."
#read -p  "Enable email service [y/n]: " EMAIL_SERVICE
#if [ ${EMAIL_SERVICE} = "y" ];
#	then
#		EMAIL_SERVICE="yes"
#		read -p "Enter an administration email address [default=none]: " ADMIN_EMAIL
#fi
#if [ ${EMAIL_SERVICE} = "n" ];
#	then
#		EMAIL_SERVICE="no"
#fi

# set up the Expedius user login information into the Tomcat Users file. 
sed -e "s|.*</tomcat-users>.*|\<role rolename=\"expedius\"\/\>\<user username=\"${EXPEDIUS_USERNAME}\" password=\"${EXPEDIUS_PASSWORD}\" roles=\"expedius\"\/\>\<\/tomcat-users\>|g" docker/tomcat_expedius/conf/tomcat-users.xml > tomcat-users.xml.tmp
mv tomcat-users.xml.tmp docker/tomcat_expedius/conf/tomcat-users.xml

# get the Oscar context path and then set everything in the expedius.properties file.
sed -e "s|EMR_CONTEXT_PATH=.*|EMR_CONTEXT_PATH=${OSCAR_CONTEXT}|g" -e "s|ADMIN_EMAIL=.*|ADMIN_EMAIL=${ADMIN_EMAIL}|g" -e "s|EMAIL_ON=.*|EMAIL_ON=${EMAIL_SERVICE}|g" -e "s|LOG_PATH=.*|LOG_PATH=${APP_DATA}\/logs\/|g" -e "s|TOMCAT_ROOT=.*|TOMCAT_ROOT=${TOMCAT_PATH}|g" -e "s|EXCELLERIS=.*|EXCELLERIS=true|g" -e "s|IHAPOI=.*|IHAPOI=false|g" -e "s|EMR_HOST_NAME=.*|EMR_HOST_NAME=${OSCAR_DN}|g" -e "s|EMR_WS_USERNAME=.*|EMR_WS_USERNAME=${OSCAR_USERNAME}|g" -e "s|EMR_WS_PASSWORD=.*|EMR_WS_PASSWORD=${OSCAR_PASSWORD}|g" -e "s|SERVICE_NUMBER=.*|SERVICE_NUMBER=${OSCAR_NUMBER}|g" -e "s|TRUSTSTORE_URL=.*|TRUSTSTORE_URL=${APP_DATA}\/.ssl\/expedius_trust.jks|g" -e "s|KEYSTORE_URL=.*|KEYSTORE_URL=${APP_DATA}\/.ssl\/expedius_key.jks|g" -e "s|DATA_PATH=.*|DATA_PATH=${APP_DATA}\/.appdata\/|g" -e "s|HL7_SAVE_PATH=.*|HL7_SAVE_PATH=${APP_DATA}\/hl7\/|g" -e "s|ACKNOWLEDGE_DOWNLOADS=.*|ACKNOWLEDGE_DOWNLOADS=true|g" docker/tomcat_expedius/conf/templates/expedius.properties > expedius.properties.tmp
mv -f expedius.properties.tmp volumes/expedius/expedius.properties

# set up trust store with an Oscar SSL trust cert
#echo "Installing the Oscar EMR SSL certificate into the Expedius TrustStore..."
#openssl s_client -showcerts -connect ${OSCAR_DN} </dev/null 2>/dev/null|openssl x509 -outform PEM >${OSCAR_CONTEXT}.pem
#keytool -import -v -trustcacerts -alias oscar -file ${OSCAR_CONTEXT}.pem -keystore ${APP_DATA}\/.ssl\/expedius_truststore.pkcs12 -storepass 3mr1esting89! -storetype PKCS12

echo "------##### Expedius Interface Login #####------"
echo
echo "      username: "${EXPEDIUS_USERNAME}
echo "      password: "${EXPEDIUS_PASSWORD}
echo "      url:       https://<your url>:8081/Expedius"
echo
echo "------####################################------"

echo "------##### OSCAR Expedius Account #####------"
echo
echo "      username: "${OSCAR_USERNAME}
echo "      password: "${OSCAR_PASSWORD}
echo "      pin:      "${OSCAR_PIN}
echo "      Oscar ID  "${OSCAR_NUMBER}
echo
echo "------##################################------"
