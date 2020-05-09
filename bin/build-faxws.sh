#!/bin/bash

cd docker/faxws

## Clone
git clone https://bitbucket.org/openoscar/faxws.git

cd faxws

git checkout feature/make-db-configurable
# git checkout origin/release

echo "Build FaxWs with Maven..."

mvn clean
mvn package

