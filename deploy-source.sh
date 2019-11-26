#!/bin/sh

set -euxo

echo "This deploys a fresh oscar from source."

echo "Compiling OSCAR. This may take some time...."
docker-compose run builder ./bin/build-oscar.sh

cp ./oscar/target/oscar-14.0.0-SNAPSHOT.war oscar.war

./bin/run.sh

