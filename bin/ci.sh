#!/bin/bash
# This script is intended to freshly set up an Oscar environment from scratch.
# It can be called by Jenkins for example, to ensure nothing is broken as updates are made.

./openosp setup --noinput
./openosp bootstrap --noinput
./openosp start
./openosp health

