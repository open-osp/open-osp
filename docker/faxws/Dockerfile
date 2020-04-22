FROM tomcat:7

# get the mysql driver inplace
RUN mv mysql-connector-java*.jar /usr/local/tomcat/lib/

# Deploy the war file
RUN mv FaxWs*.war /usr/local/tomcat/webapps/faxWs.war

# catalina start
CMD ["catalina.sh", "run"]