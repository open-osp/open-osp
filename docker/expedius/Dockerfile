FROM tomcat:9.0.56-jre8

# Fetch Expedius binary
RUN wget https://bitbucket.org/colcamexdev/expediusbinary/downloads/Expedius-4.12.21.war
RUN mv Expedius-4.12.21.war /usr/local/tomcat/webapps/Expedius.war

# Modified server.xml is set with a 8444 port 
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

RUN useradd --uid 10001 expedius \
    && chown -R expedius:expedius /usr/local/tomcat/

USER expedius

# catalina start
CMD ["catalina.sh", "run"]
