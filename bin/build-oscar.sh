#!/bin/bash


set -uxo

./bin/clone.sh

cd docker/oscar/oscar

# increase java perm and gen memory for build
# other switches can be added here for debugging the build.
export MAVEN_OPTS="-Xms640m -Xmx640m -Xss512k -XX:NewRatio=4"

# this repository should have passed unit testing and mvn verify 
# on the cis before being built here.
mvn clean package
#mvn -Dmaven.test.skip=true clean package

chmod 777 -R ./target/

