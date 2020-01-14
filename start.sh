#!/bin/bash

docker-compose stop tomcat_oscar
docker-compose rm tomcat_oscar

docker-compose stop nginx
docker-compose rm nginx

docker-compose up -d nginx
docker-compose up -d db
sleep 5
docker-compose up -d tomcat_oscar

