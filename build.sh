#!/bin/bash

cd oscar
apt-get update
apt-get install -y maven
mvn -Dmaven.test.skip=true clean verify