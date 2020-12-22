#!/bin/bash

keytool -noprompt -importcert -alias oscar -keystore /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/cacerts -storepass changeit -file /usr/local/tomcat/conf/ssl.crt



exec "$@"
