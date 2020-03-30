#!/bin/bash


set -uxo

./bin/clone.sh

cd oscar

#mvn clean verify
#mvn package

mvn -Dmaven.test.skip=true clean verify
mvn package -Dmaven.test.skip=true

chmod 777 -R ./target/

