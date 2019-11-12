#!/bin/bash


set -uxo

branch=${OSCAR_BRANCH:-master}
repo=${OSCAR_REPO:-https://bitbucket.org/oscaremr/oscar.git}

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone --branch $branch $repo oscar
fi

cd oscar
apt-get update
apt-get install -y maven
mvn -Dmaven.test.skip=true clean verify
mvn package -Dmaven.test.skip=true

