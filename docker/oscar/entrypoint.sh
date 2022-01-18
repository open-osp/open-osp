#!/bin/bash

keytool -noprompt -importcert -alias oscar -keystore /usr/local/openjdk-8/lib/security/cacerts -storepass changeit -file /usr/local/tomcat/conf/ssl.crt



exec "$@"
