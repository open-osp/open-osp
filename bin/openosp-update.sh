#!/bin/sh

echo "Updating OpenOSP image and restarting. This only works if you are set to the release tag."

docker pull openosp/open-osp:release
docker pull openosp/expedius:latest
docker pull openosp/faxws:latest

docker-compose --compatibility up -d

