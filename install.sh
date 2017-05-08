#!/bin/sh
echo "Cloning oscar from bitbucket"
git clone --depth 1 https://bitbucket.org/oscaremr/oscar.git
echo "Disabling Caisi"
cp code/CaisiIntegratorUpdateTask.java oscar/src/main/java/org/oscarehr/PMmodule/caisi_integrator/
#cp code/Security.java oscar/src/main/java/org/oscarehr/common/model/
cd oscar
echo "Compiling OSCAR. This may take some time...."
mvn package -Dmaven.test.skip=true
cd ..
echo "Setting up docker containers. This may take some time...."
docker-compose up -d
echo "Waiting for containers to initialize (1 min)"
sleep 60
echo "Copying configuration files.."
docker exec -d dockeroscar15_tomcat_oscar_1 chmod 755 /usr/local/tomcat/conf/copy.sh
docker exec -d dockeroscar15_tomcat_oscar_1 /usr/local/tomcat/conf/copy.sh
echo "OSCAR is set up at http://localhost:8091/oscar_mcmaster"
echo "You may have to restart the container http://localhost:8091/  (oscar/oscar)"
echo "Thank You.."
echo "Visit our website for more info: http://nuchange.ca"