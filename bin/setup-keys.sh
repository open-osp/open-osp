#!/bin/bash

if [ ! -f ./volumes/ssl.key ] || [ ! -f ./volumes/ssl.crt ] ; then 
    echo "Generating self-signed cert for internal use. The common name is 'faxws' since that is the only internally validated name."
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=faxws" -keyout ./volumes/ssl.key -out ./volumes/ssl.crt
fi

