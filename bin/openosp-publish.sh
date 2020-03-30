#!/bin/bash

set -exo

VER=$(date +"%Y.%m.%d")
docker tag openosp/open-osp:latest openosp/open-osp:$VER
docker login --username=$DOCKERHUB_USERNAME --password=$DOCKERHUB_PASSWORD
docker push openosp/open-osp:$VER
docker push openosp/open-osp:latest

