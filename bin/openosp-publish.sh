#!/bin/bash

set -exo

if [[ -z $1 ]]; then
  VER=$(date +"%Y.%m.%d")
else
  VER=$1
fi
docker tag openosp/open-osp:latest openosp/open-osp:$VER
docker login --username=$DOCKERHUB_USERNAME --password=$DOCKERHUB_PASSWORD
docker push openosp/open-osp:$VER
docker push openosp/open-osp:latest

