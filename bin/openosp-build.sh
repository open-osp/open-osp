#!/bin/sh

set -euxo

echo "This deploys a fresh oscar from source."

echo "Compiling OSCAR. This may take some time...."
docker-compose -f docker-compose.admin.yml run builder ./bin/build-oscar.sh
OSCAR_OUTPUT=docker/tomcat_oscar
if [ ! -f $OSCAR_OUTPUT/oscar.war ]; then
  echo "Building oscar.war from cloned Oscar REPO"
  mv ./oscar/target/oscar-*-SNAPSHOT.war $OSCAR_OUTPUT/oscar.war
fi

export DRUGREF_WAR=${DRUGREF_WAR:-"http://bool.countable.ca/drugref2.war"}

if [ ! -f drugref2.war ]; then
  # Latest OscarBC as of Nov 13 2019.
  docker run -v $(pwd):/code/ busybox sh -c "cd /code/ && wget $DRUGREF_WAR -O $OSCAR_OUTPUT/drugref2.war"
fi

docker-compose build tomcat_oscar

