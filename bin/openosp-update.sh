#!/bin/sh

ARCH=`uname -m`
if [[ $ARCH == 'arm64' || $ARCH == 'aarch64' ]]; then
  echo "Not pulling pre-built docker images as you are on an ARM machine; you'll need to build them yourself."
else
  echo "Updating OpenOSP image and restarting. This only works if you are set to the release tag."

  docker pull openosp/open-osp:release
  docker pull openosp/expedius:latest
  docker pull openosp/faxws:latest

  docker compose  --compatibility up -d
fi
