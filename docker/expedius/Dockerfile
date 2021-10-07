FROM tomcat:8.5-jre8

# Fetch Expedius binary
RUN wget https://bitbucket.org/colcamexdev/expediusbinary/downloads/Expedius-4.12.19.war
RUN mv Expedius-4.12.19.war /usr/local/tomcat/webapps/Expedius.war

# Modified server.xml is set with a 8444 port 
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

# catalina start
CMD ["catalina.sh", "run"]
