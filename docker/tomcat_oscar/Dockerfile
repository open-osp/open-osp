FROM tomcat:7-jre8

#ENV JDBC_URL jdbc:mysql://db:3306/oscar?autoReconnect=true&zeroDateTimeBehavior=round&useOldAliasMetadataBehavior=true&jdbcCompliantTruncation=false
#ENV JDBC_USER root
#ENV JDBC_PASS liyi

ADD oscar.war /usr/local/tomcat/webapps/oscar.war
ADD drugref2.war /usr/local/tomcat/webapps/drugref2.war

ADD ./conf/logging.properties /usr/local/tomcat/conf/logging.properties
ADD ./conf/logging-servlet.properties /usr/local/tomcat/conf/logging-servlet.properties
ADD ./conf/templates/oscar_mcmaster_bc.properties /root/oscar.properties
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
ADD ./conf/drugref2.properties /root/drugref2.properties
ADD ./conf/index.jsp /usr/local/tomcat/webapps/ROOT/index.jsp

# Integrator directory
RUN mkdir -p /var/lib/bc-integrator/export

CMD ["catalina.sh", "run"]
