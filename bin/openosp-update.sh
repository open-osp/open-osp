#!/bin/sh

docker pull openosp/open-osp:latest
docker-compose restart tomcat_oscar

