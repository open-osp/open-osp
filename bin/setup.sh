#!/bin/bash

if [ ! -f ./volumes/ssl.key ] || [ ! -f ./volumes/ssl.crt ] ; then 
    echo "Generating self-signed cert for temporary use. Please replace with a CA signed one."
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=CA/ST=BC/L=Vancouver/O=OpenOSP/CN=${HOST:-openosp.ca}" -keyout ./volumes/ssl.key -out ./volumes/ssl.crt
fi

