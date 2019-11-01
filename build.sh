#!/bin/bash

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone --depth 1 https://bitbucket.org/oscaremr/oscar.git
fi

cd oscar
apt-get update
apt-get install -y maven
mvn -Dmaven.test.skip=true clean verify
mvn package -Dmaven.test.skip=true

