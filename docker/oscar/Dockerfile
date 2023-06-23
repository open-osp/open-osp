FROM tomcat:9.0.76-jdk8-corretto

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

# Use the TZ env var instead
#RUN rm -f /etc/localtime \
#    && ln -s /usr/share/zoneinfo/America/Vancouver /etc/localtime

# Install requirements for wkhtmltopdf
# These were reverse engineered from the .deb package for Debian
RUN apt-get update \
    && apt-get -qq -y --no-install-recommends install ca-certificates fontconfig libc6 libfreetype6 libjpeg62-turbo libpng16-16 libssl1.1 libstdc++6 libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g \
    && apt-get clean

ADD oscar.war /usr/local/tomcat/webapps/oscar.war
ADD drugref2.war /usr/local/tomcat/webapps/drugref2.war

ADD ./conf/logging.properties /usr/local/tomcat/conf/logging.properties
ADD ./conf/logging-servlet.properties /usr/local/tomcat/conf/logging-servlet.properties
ADD ./conf/oscar_mcmaster_bc.properties /root/oscar.properties
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
ADD ./conf/drugref2.properties /root/drugref2.properties
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml
ADD ./melody-web.xml /tmp/melody-web.xml

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
