#!/bin/bash

docker-compose build tomcat_oscar
docker tag open-osp_tomcat_oscar openosp-oscar:latest
docker push openosp-oscar:latest

