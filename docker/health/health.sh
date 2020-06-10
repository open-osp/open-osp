#!/bin/sh

set -euxo

ping -c 1 faxws
ping -c 1 expedius
ping -c 1 db
ping -c 1 oscar

faxws_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik -u faxws:abc123 https://faxws/faxWs`
faxws_allow=`curl -Ik -u faxws:abc123 https://faxws/faxWs 2>/dev/null | grep "Allow" | head -1 | cut -d":" -f2`
expedius_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik http://expedius:8081/Expedius/`
drugref_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik http://oscar:8080/drugref2/`
oscar_http_code=`curl -s -o /dev/null -w "%{http_code}" -Ik -X POST -u openosp:Password123 http://oscar:8080/oscar/ws/LoginService`

/health-checker.sh $faxws_http_code "401"
/health-checker.sh $expedius_http_code "200"
/health-checker.sh $drugref_http_code "200"
/health-checker.sh $oscar_http_code "500"
