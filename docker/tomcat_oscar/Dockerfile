FROM tomcat:7-jre8

ADD oscar.war /usr/local/tomcat/webapps/oscar.war
ADD drugref2.war /usr/local/tomcat/webapps/drugref2.war

# RUN mkdir -p /var/lib/OscarDocument/login

# ADD ./conf/templates/AcceptableUseAgreement.txt /var/lib/OscarDocument/login/AcceptableUseAgreement.txt
# ADD ./conf/templates/login_page_template.txt /var/lib/OscarDocument/login/.env

ADD ./conf/logging.properties /usr/local/tomcat/conf/logging.properties
ADD ./conf/logging-servlet.properties /usr/local/tomcat/conf/logging-servlet.properties
ADD ./conf/templates/oscar_mcmaster_bc.properties /root/oscar.properties
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
ADD ./conf/drugref2.properties /root/drugref2.properties
ADD ./conf/index.jsp /usr/local/tomcat/webapps/ROOT/index.jsp
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

# Integrator directory
RUN mkdir -p /var/lib/bc-integrator/export

CMD ["catalina.sh", "run"]
