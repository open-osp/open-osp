#!/bin/bash

docker-compose build tomcat_oscar
docker tag open-osp_tomcat_oscar openosp-oscar:latest
docker push openosp-oscar:latest

docker-compose build tomcat_expedius
docker tag open-osp_tomcat_expedius colcamex-expedius:latest
docker push colcamex-expedius:latest