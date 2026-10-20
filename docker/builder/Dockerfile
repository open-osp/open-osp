FROM maven:3.9-eclipse-temurin-8

# This container builds oscar, and runs mvn tests.
# Install the mariadb-client so we can run tests.
# (Replaces the former FROM openjdk:8, removed from Docker Hub in 2025.)
RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-client \
    && apt-get clean
