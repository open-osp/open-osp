FROM tomcat:9.0.102-jre8-temurin-jammy

# Set the locale
RUN apt-get update && apt-get install -y locales curl iputils-ping

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

RUN apt-get update \
    && apt-get install -y --no-install-recommends gettext \
    && apt-get clean

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
    && rm -f /tmp/ziupdater.jar /tmp/tzdata.tar.gz

# Install requirements for wkhtmltopdf
# TODO this needs to be adapted to execute in different environments than just Ubuntu Jammy.

# UBUNTU Jammy
RUN apt-get update \
    && apt-get -qq -y --no-install-recommends install ca-certificates fontconfig libc6 libfreetype6 libjpeg-turbo8 libpng16-16 libssl3 libstdc++6 libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g \
    && apt-get clean;

# Other debian installs
#RUN apt-get update \
#    && apt-get -qq -y --no-install-recommends install ca-certificates fontconfig libc6 libfreetype6 libjpeg62-turbo libpng16-16 libssl1.1 libstdc++6 libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g \
#    && apt-get clean;

ADD oscar.war /usr/local/tomcat/webapps/oscar.war
ADD drugref2.war /usr/local/tomcat/webapps/drugref2.war

ADD ./conf/logging.properties /usr/local/tomcat/conf/logging.properties
ADD ./conf/logging-servlet.properties /usr/local/tomcat/conf/logging-servlet.properties
ADD ./conf/oscar_mcmaster_bc.properties /root/oscar.properties
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
ADD ./conf/drugref2.properties /root/drugref2.properties
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml
ADD ./conf/context.xml /usr/local/tomcat/conf/context.xml
# ADD ./melody-web.xml /tmp/melody-web.xml

#clean out Tomcat garbage from the ROOT folder
RUN rm -rf /usr/local/tomcat/webapps/ROOT/*.*

#Add a proper favicon and the index redirect for OSCAR
ADD ./index.jsp /usr/local/tomcat/webapps/ROOT/index.jsp
ADD ./openosp_favicon.ico /usr/local/tomcat/webapps/ROOT/favicon.ico

ADD ./oscar/database/mysql/ /oscar-mysql-scripts/
ADD ./bin/startup.sh /startup.sh

# Integrator directory
RUN mkdir -p /var/lib/bc-integrator/export

ADD ./entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["/startup.sh"]
