# Overlay for all Tomcat/JRE8 app containers (oscar, expedius, faxws).
# Updates BOTH timezone databases a Java app container depends on:
#   1. JVM tzdb.dat  <- donor: eclipse-temurin:8-jre (ships IANA tzdata 2026b, same vendor/format)
#   2. OS zoneinfo   <- donor: ubuntu:22.04 + tzdata (IANA 2026c)
# Usage: docker build -f docker/tzupdate/jre.Dockerfile --build-arg BASE=<image> .
ARG BASE

FROM eclipse-temurin:8-jre AS jvmdonor

FROM ubuntu:22.04 AS osdonor
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*

FROM ${BASE}
COPY --from=jvmdonor /opt/java/openjdk/lib/tzdb.dat /opt/java/openjdk/lib/tzdb.dat
COPY --from=osdonor /usr/share/zoneinfo /usr/share/zoneinfo
