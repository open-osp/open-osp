#!/bin/sh

echo "Updating OpenOSP image and restarting. This only works if you are set to the release tag."

docker pull openosp/open-osp:release
docker-compose --compatibility up -d oscar

