#!/bin/sh

set -euxo

#ping -c 1 expedius
#ping -c 1 db
#ping -c 1 oscar
#ping -c 1 faxws

openssl x509 -in /usr/local/tomcat/conf/ssl.crt -out /tmp/ssl.pem -outform PEM

faxws_http_code=$(curl -s -o /dev/null -w "%{http_code}" -Ik -O --cacert /tmp/ssl.pem https://faxws/faxWs || true)
/health-checker.sh "$faxws_http_code" "404"

expedius_http_code=$(curl -s -o /dev/null -w "%{http_code}" -Ik http://expedius:8081/Expedius/ || true)
/health-checker.sh "$expedius_http_code" "200"

oscar_http_code=$(curl -s -o /dev/null -w "%{http_code}" -Ik -O https://oscar/oscar/ops/health/heartbeat || true)
/health-checker.sh "$oscar_http_code" "200"

drugref_http_code=$(curl -s -o /dev/null -w "%{http_code}" -Ik -O https://oscar/drugref2/ || true)
/health-checker.sh "$drugref_http_code" "200"