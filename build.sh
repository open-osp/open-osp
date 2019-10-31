#!/bin/bash

cd oscar
apt-get update
apt-get install -y maven
mvn package -Dmaven.test.skip=true

