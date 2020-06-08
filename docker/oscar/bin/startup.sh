#!/bin/bash

set -euxo

catalina.sh start

rm -rf /usr/local/tomcat/webapps/docs
rm -rf /usr/local/tomcat/webapps/examples
rm -rf /usr/local/tomcat/webapps/manager
rm -rf /usr/local/tomcat/webapps/host-manager

tail -f /usr/local/tomcat/logs/catalina.out

echo "Updating drugref"
curl -v -H "content-type:text/xml" \ 
    http://oscar:8080/drugref2/DrugrefService --data @bin/drugref2/updatedrugref.xml