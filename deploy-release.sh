#!/bin/bash

set -euxo

cp ./conf/oscar_mcmaster_bc.properties oscar_mcmaster_bc.properties
docker-compose run builder ./bin/clone.sh

./bin/run.sh

