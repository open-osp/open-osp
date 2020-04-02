#!/bin/sh

echo "Updating OpenOSP image and restarting."

docker pull openosp/open-osp:latest
docker-compose restart oscar

