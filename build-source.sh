#!/bin/sh

set -euxo

echo "This deploys a fresh oscar from source."

echo "Compiling OSCAR. This may take some time...."
docker-compose -f docker-compose.admin.yml run builder ./bin/build-oscar.sh

cp ./oscar/target/oscar-*-SNAPSHOT.war oscar.war

export DRUGREF_WAR=${DRUGREF_WAR:-"http://bool.countable.ca/drugref2.war"}

if [ ! -f drugref2.war ]; then
  # Latest OscarBC as of Nov 13 2019.
  docker run -v $(pwd):/code/ busybox sh -c "cd /code/ && wget $DRUGREF_WAR -O drugref2.war"
fi

docker-compose build tomcat_oscar

