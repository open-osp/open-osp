FROM tomcat:7

RUN apt-get update \
#    && apt-get install -y maven \
    && apt-get install -y zip \
    && apt-get install -y --no-install-recommends gettext \
    && apt-get clean


#RUN wget -P /opt https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/5.2.4/flyway-commandline-5.2.4-linux-x64.tar.gz && \
#    cd /opt && \
#    tar -xvf flyway-commandline-5.2.4-linux-x64.tar.gz && \
#    rm flyway-commandline-5.2.4-linux-x64.tar.gz && \
#    wget -P /opt https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492-linux.zip && \
#    unzip sonar-scanner-cli-3.3.0.1492-linux.zip && \
#    rm sonar-scanner-cli-3.3.0.1492-linux.zip

#ENV PATH $PATH:/opt/flyway-5.2.4:/opt/sonar-scanner-3.3.0.1492-linux/bin
#ENV SONAR_RUNNER_HOME /opt/sonar-scanner-3.3.0.1492-linux

# Deploy the war file
ADD ./faxws/target/FaxWs*SNAPSHOT.war /usr/local/tomcat/webapps/faxWs.war

ADD ./faxws/database/mysql/V1.0__create_database.sql /create_database.sql
# move the JDBC Jar
ADD ./faxws/target/FaxWs-1.0.0-SNAPSHOT/WEB-INF/lib/mysql-connector-java*.jar /usr/local/tomcat/lib/

# Add environment variables for creds
ENV CONFIG_FILES /usr/local/tomcat/conf/context.xml
ADD ./entrypoint.sh /entrypoint.sh
ADD ./context.xml.template /usr/local/tomcat/conf/

# necessary for HTTPS
ADD ./conf/server.xml /usr/local/tomcat/conf/server.xml

ENTRYPOINT [ "/entrypoint.sh" ]

# catalina start
CMD ["catalina.sh", "run"]
