#!/bin/bash

cd docker/faxws

## Clone
git clone https://bitbucket.org/openoscar/faxws.git

cd faxws

echo "Remove context xml so we can replace it after WAR extraction."
rm src/main/webapp/META-INF/context.xml

echo "Build FaxWs with Maven..."

if [[ "${TEST_DURING_BUILD:-}" ]]; then
  mvn clean package
else
  mvn -Dcheckstyle.skip -Dmaven.test.skip=true clean package
fi
