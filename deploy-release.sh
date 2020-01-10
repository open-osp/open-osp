#!/bin/bash

set -euxo

# OscarBC built commit (for db bootstrap)
# This should match the commit used by the WAR file.
export OSCAR_TREEISH=97292c71a3af47e0539b2b7336b9b06f16b8b090

docker-compose run builder ./bin/clone.sh

./bin/run.sh

