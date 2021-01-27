#!/bin/bash

set -euxo

#echo "Updating drugref"
#curl -v -H "content-type:text/xml" \ 
#    http://oscar:8080/drugref2/DrugrefService --data @bin/drugref2/updatedrugref.xml

catalina.sh start

# move here to make sure that webapps/oscar is created 
mv /tmp/melody-web.xml /usr/local/tomcat/webapps/oscar/WEB-INF/web.xml

tail -f /usr/local/tomcat/logs/catalina.out

