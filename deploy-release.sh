#!/bin/bash

set -euxo

cp ./conf/oscar_mcmaster_bc.properties oscar.properties
cp ./conf/drugref2.properties drugref2.properties
docker-compose run builder ./bin/clone.sh

./bin/run.sh

