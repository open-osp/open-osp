#!/bin/bash


set -uxo

if [ -f "./local.env" ]
then
    source ./local.env
fi

./bin/clone.sh ${OSCAR_REPO:-""} ${OSCAR_TREEISH:-""}

cd docker/oscar/oscar

# increase java perm and gen memory for build
# other switches can be added here for debugging the build.
export MAVEN_OPTS="-Xms640m -Xmx640m -Xss512k -XX:NewRatio=4 -Djava.net.preferIPv4Stack=true"

# this repository should have passed unit testing and mvn verify 
# on the cis before being built here.
if [[ -z "${TEST_DURING_BUILD:-}" ]]
then
    mvn -Dmaven.test.skip=true clean package
else
    mvn clean package
fi

chmod 777 -R ./target/

