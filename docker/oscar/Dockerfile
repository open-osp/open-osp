FROM tomcat:9-jre8

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

ADD oscar.war /usr/local/tomcat/webapps/oscar.war
ADD drugref2.war /usr/local/tomcat/webapps/drugref2.war

ADD ./conf/logging.properties /usr/local/tomcat/conf/logging.properties
ADD ./conf/logging-servlet.properties /usr/local/tomcat/conf/logging-servlet.properties
ADD ./conf/oscar_mcmaster_bc.properties /root/oscar.properties
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
ADD ./conf/drugref2.properties /root/drugref2.properties
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml
ADD ./index.jsp /usr/local/tomcat/ROOT/index.jsp
ADD ./drugref2 /usr/local/tomcat/bin/drugref2

ADD ./oscar/database/mysql/ /oscar-mysql-scripts/
ADD ./bin/startup.sh /startup.sh

#Identify the timezone you want to configure and create a symlink:
RUN rm -f /etc/localtime \
    && ln -s /usr/share/zoneinfo/America/Vancouver /etc/localtime


# Integrator directory
RUN mkdir -p /var/lib/bc-integrator/export

ADD ./entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["/startup.sh"]
