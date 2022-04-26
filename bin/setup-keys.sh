#!/bin/bash

if [ ! -f ./volumes/ssl.key ] || [ ! -f ./volumes/ssl.crt ] ; then 
    echo "Generating self-signed cert for internal use. The common name is 'faxws' since that is the only internally validated name."
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=faxws" -keyout ./volumes/ssl.key -out ./volumes/ssl.crt
fi

# Create an empty chain.pem file
# If an empty file doesn't exist, then Docker adds chain.pem as a **directory** instead of a file,
# which results in an "Error response from daemon: error while creating mount source path './volumes/chain.pem': chown ./volumes/chain.pem: operation not permitted"
# when bringing up the openosp image
if [ ! -f ./volumes/chain.pem ] ; then
    touch ./volumes/chain.pem
fi
