FROM openjdk:8

# This container builds oscar, and runs mvn tests.
# Install the mariadb-client so we can run tests.
RUN apt-get update \
    && apt-get install -y --no-install-recommends maven mariadb-client \
    && apt-get clean
