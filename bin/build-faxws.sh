#!/bin/bash

cd docker/faxws

## Clone
git clone https://bitbucket.org/openoscar/faxws.git

cd faxws

echo "Remove context xml so we can replace it after WAR extraction."
rm src/main/webapp/META-INF/context.xml

echo "Build FaxWs with Maven..."

mvn clean
mvn package

