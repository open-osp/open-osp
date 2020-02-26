#!/bin/bash

#TODO, make it more clear this job clears the local DB
#./purge.sh
#./build-source.sh

VER=$(date +"%Y.%m.%d")
docker tag openosp/open-osp:latest openosp/open-osp:$VER
docker push openosp/open-osp:$VER
docker push openosp/open-osp:latest

