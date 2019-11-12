#!/bin/bash

branch=${OSCAR_BRANCH:-https://bitbucket.org/oscaremr/oscar.git}
repo=${OSCAR_REPO:-master}

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
#    git clone --depth 1 https://bitbucket.org/oscaremr/oscar.git
    git clone --single-branch --branch $branch $repo
fi

cd oscar
apt-get update
apt-get install -y maven
mvn -Dmaven.test.skip=true clean verify
mvn package -Dmaven.test.skip=true

