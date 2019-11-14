#!/bin/sh

set -euxo

echo "This script is a fork of "Oscar in a Box" by http://nuchange.ca"

echo "Destroy any old instance (keeping database)."
docker-compose down

export OSCAR_WAR=./oscar/target/oscar-14.0.0-SNAPSHOT.war

echo "Compiling OSCAR. This may take some time...."
docker-compose run builder ./bin/build.sh

./bin/run.sh

