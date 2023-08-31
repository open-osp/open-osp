#!/bin/bash

keytool -noprompt -importcert -alias oscar -keystore ${JAVA_HOME}/lib/security/cacerts -storepass changeit -file /usr/local/tomcat/conf/ssl.crt

for filename in $ENVSUBST_CONFIG_FILES; do
    if [ -f $filename.template ]; then
        echo "Substituting $filename"
        envsubst < $filename.template \
                 > $filename
    fi
done


exec "$@"

