#!/bin/bash

set -uxo

if [ -f './local.env' ]; then
  source ./local.env
fi

./bin/clone.sh "${OSCAR_REPO:-""}" "${OSCAR_TREEISH:-""}"

if [ ! -d docker/oscar/oscar ]; then
  echo "ERROR: docker/oscar/oscar was not created. Check the output of ./bin/clone.sh above." >&2
  exit 1
fi

cd docker/oscar/oscar || { echo "ERROR: unable to enter docker/oscar/oscar." >&2; exit 1; }

# increase java perm and gen memory for build
# other switches can be added here for debugging the build.
export MAVEN_OPTS="-Xms2g -Xmx4g -Djava.net.preferIPv4Stack=true"

# this repository should have passed unit testing and mvn verify 
# on the cis before being built here.
if [[ "${TEST_DURING_BUILD:-}" ]]; then
  mvn clean package
elif [[ "${DEVELOPMENT_MODE:-}" ]]; then
  mvn -T 1C install --offline
else
  mvn -Dcheckstyle.skip=true -Dmaven.test.skip=true clean package
fi

chmod 777 -R ./target/
