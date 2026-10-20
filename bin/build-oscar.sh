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

# The repo is bind-mounted from the host, so git inside the container
# may refuse it as "dubious ownership" unless it's marked safe.
git config --global --add safe.directory "$(pwd)"

# Use the latest tag of the OSCAR checkout as the build number,
# unless BUILD_NUMBER was already passed in (e.g. by CI).
if [[ -z "${BUILD_NUMBER:-}" ]]; then
  BUILD_NUMBER="$(git describe --tags --abbrev=0 2>/dev/null || echo 0)"
fi
export BUILD_NUMBER

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
