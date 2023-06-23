#!/bin/bash

keytool -noprompt -importcert -alias oscar -keystore ${JAVA_HOME}/lib/security/cacerts -storepass changeit -file /usr/local/tomcat/conf/ssl.crt



exec "$@"
