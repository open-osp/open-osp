#!/bin/bash

set -euxo

#echo "Updating drugref"
#curl -v -H "content-type:text/xml" \ 
#    http://oscar:8080/drugref2/DrugrefService --data @bin/drugref2/updatedrugref.xml

catalina.sh start

tail -f /usr/local/tomcat/logs/catalina.out

