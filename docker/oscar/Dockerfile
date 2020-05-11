FROM tomcat:7-jre8

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

ADD ./oscar/database/mysql/ /oscar-mysql-scripts/

# Integrator directory
RUN mkdir -p /var/lib/bc-integrator/export

CMD ["catalina.sh", "run"]
