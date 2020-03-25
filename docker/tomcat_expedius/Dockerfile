FROM tomcat:7

# Expedius resource directory.
RUN mkdir -p /var/lib/expedius
RUN mkdir -p /var/lib/expedius/hl7
RUN mkdir -p /var/lib/expedius/.appdata
RUN mkdir -p /var/lib/expedius/.ssl
RUN mkdir -p /var/lib/expedius/log

# Fetch and modify the properties.
ADD ./conf/expedius.properties /var/lib/expedius/expedius.properties

# Fetch and modify a tomcat-users and server config.
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml

# server.xml is set with a 8081 port 
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

# Deploy the tomcat war file.
ADD Expedius*.war /usr/local/tomcat/webapps/Expedius.war

# catalina start
CMD ["catalina.sh", "run"]