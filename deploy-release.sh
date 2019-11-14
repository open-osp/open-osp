#!/bin/sh

set -euxo

echo "Destroy any old instance."
docker-compose down

# Latest OscarBC downloaded file.
export OSCAR_WAR=${OSCAR_WAR:-./oscar-14.0.0-SNAPSHOT.war}

# Latest OscarBC as of Nov 13 2019.
wget http://jenkins.oscar-emr.com:8080/job/oscar-bc/5/artifact/target/oscar-14.0.0-SNAPSHOT.war -O $OSCAR_WAR

# OscarBC built commit (for db bootstrap)
export OSCAR_TREEISH=97292c71a3af47e0539b2b7336b9b06f16b8b090

docker-compose run builder ./bin/clone.sh

./bin/run.sh

