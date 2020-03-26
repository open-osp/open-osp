FROM tomcat:7

# Fetch a modified tomcat-users and server config.
ADD ./conf/tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml

# Modified server.xml is set with a 8444 port 
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

# Deploy the tomcat war file.
ADD Expedius*.war /usr/local/tomcat/webapps/Expedius.war

# catalina start
CMD ["catalina.sh", "run"]