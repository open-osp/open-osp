FROM openjdk:8

# This container builds oscar, and runs mvn tests.

RUN apt-get update \
 && apt-get install -y maven mariadb-client

# install the mysql client above so we run the tests.

