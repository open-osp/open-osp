#!/bin/bash

keytool -noprompt -importcert -alias oscar -keystore /opt/java/openjdk/lib/security/cacerts -storepass changeit -file /usr/local/tomcat/conf/ssl.crt



exec "$@"
