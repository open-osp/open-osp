FROM tomcat:jre21-temurin-noble

RUN apt update && apt install --only-upgrade ca-certificates

# Fetch Expedius binary
ARG EXPEDIUS_URL=https://github.com/open-osp/expedius/releases/download/latest/Expedius-rc4.11.26.war
ARG EXPEDIUS_SHA256=fa663e95dec82b85f51e7c011009a46055651d288c2666a6cee6bcc1c7d7776b
RUN wget -q -O /tmp/Expedius.war "${EXPEDIUS_URL}" \
    && echo "${EXPEDIUS_SHA256}  /tmp/Expedius.war" | sha256sum -c - \
    && mv /tmp/Expedius.war /usr/local/tomcat/webapps/Expedius.war

# Update the JRE timezone data. The jar is copied into the build context by bin/openosp-build.sh.
# ziupdater only accepts file:// URLs, so the IANA tzdata bundle is downloaded first.
ARG TZDATA_URL="https://data.iana.org/time-zones/tzdata-latest.tar.gz"
ADD ziupdater-1.1.3.1.jar /tmp/ziupdater.jar

RUN echo "Installing Java TZUpdater..." \
    && echo "Java TZDB before update:" \
    && java -jar /tmp/ziupdater.jar -V \
    && curl -fsSL "${TZDATA_URL}" -o /tmp/tzdata.tar.gz \
    && echo "Updating Java TZDB..." \
    && java -jar /tmp/ziupdater.jar -l file:///tmp/tzdata.tar.gz \
    && echo "Java TZDB after update:" \
    && java -jar /tmp/ziupdater.jar -V \
    && echo "Updating system zoneinfo..." \
    && mkdir -p /tmp/tzdata \
    && tar -xzf /tmp/tzdata.tar.gz -C /tmp/tzdata \
    && cd /tmp/tzdata \
    && zic -d /usr/share/zoneinfo \
         africa antarctica asia australasia europe northamerica \
         southamerica etcetera backward factory \
    && cp zone.tab zone1970.tab iso3166.tab /usr/share/zoneinfo/ \
    && echo "System tzdata version: $(cat version)" \
    && cd / \
    && rm -rf /tmp/ziupdater.jar /tmp/tzdata.tar.gz /tmp/tzdata

# Modified server.xml is set with a 8444 port 
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

# catalina start
CMD ["catalina.sh", "run"]
