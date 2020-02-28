#!/bin/bash


set -uxo

./bin/clone.sh

cd oscar
apt-get update
apt-get install -y maven
mvn -T 4 clean verify
mvn -T 4 package

