#!/bin/bash

# setup melody for existing instances
site=$(pwd | grep -oh "[^/]*$")
docker cp docker/oscar/conf/tomcat-users.xml ${site}_oscar_1:/usr/local/tomcat/conf/tomcat-users.xml
docker cp docker/oscar/melody-web.xml ${site}_oscar_1:/usr/local/tomcat/webapps/oscar/WEB-INF/web.xml

docker-compose stop oscar
docker-compose up -d oscar