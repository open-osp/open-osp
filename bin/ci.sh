#!/bin/bash
# This script is intended to freshly set up an Oscar environment from scratch.
# It can be called by Jenkins for example, to ensure nothing is broken as updates are made.

set -euxo

./openosp setup --noinput
./openosp build oscar --test
# TODO: faxws build currently fails.
#./openosp build faxws
./openosp bootstrap
./openosp start
#./openosp health

