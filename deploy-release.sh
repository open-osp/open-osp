#!/bin/bash

set -euxo

echo "This deploys an oscar from a WAR file, with DB bootstrapped from a specified matching commit."

# Latest OscarBC downloaded file.
export OSCAR_WAR=${OSCAR_WAR:-"http://jenkins.oscar-emr.com:8080/job/oscar-bc/5/artifact/target/oscar-14.0.0-SNAPSHOT.war"}

export DRUGREF_WAR=${DRUGREF_WAR:-"http://jenkins.oscar-emr.com:8080/job/drugref2/18/org.drugref\$drugref2/artifact/org.drugref/drugref2/1.0-SNAPSHOT/drugref2-1.0-SNAPSHOT.war"}

if [ ! -f oscar.war ]; then
  # TODO: support deploying a locally downloaded file directly.
  wget $OSCAR_WAR -O oscar.war
fi

if [ ! -f drugref2.war ]; then
  # Latest OscarBC as of Nov 13 2019.
  wget $DRUGREF_WAR -O drugref2.war
fi

# OscarBC built commit (for db bootstrap)
# This should match the commit used by the WAR file.
export OSCAR_TREEISH=97292c71a3af47e0539b2b7336b9b06f16b8b090

docker-compose run builder ./bin/clone.sh

./bin/run.sh

