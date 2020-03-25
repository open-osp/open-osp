#!/bin/bash

docker-compose stop tomcat_oscar
docker-compose rm tomcat_oscar

docker-compose stop tomcat_expedius
docker-compose rm tomcat_expedius

docker-compose up -d db
sleep 5

docker-compose up -d tomcat_oscar

docker-compose up -d tomcat_expedius