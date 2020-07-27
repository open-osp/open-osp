#!/bin/sh

set -euxo

ping -c 1 faxws
ping -c 1 expedius
ping -c 1 db
ping -c 1 oscar

faxws_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik -u faxws:$FAXWS_TOMCAT_PASSWORD https://faxws/faxWs`

if [ -z "$FAXWS_TOMCAT_PASSWORD" ]; then
    echo "skipping faxws, not defined."
else
    faxws_allow=`curl -Ik -u faxws:$FAXWS_TOMCAT_PASSWORD https://faxws/faxWs 2>/dev/null | grep "Allow" | head -1 | cut -d":" -f2`
    /health-checker.sh $faxws_http_code "404"
fi

expedius_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik http://expedius:8081/Expedius/`
/health-checker.sh $expedius_http_code "200"

drugref_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik http://oscar:8080/drugref2/`
/health-checker.sh $drugref_http_code "200"

oscar_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik -X POST -u openosp:Password123 http://oscar:8080/oscar/ws/LoginService`
/health-checker.sh $oscar_http_code "500"
