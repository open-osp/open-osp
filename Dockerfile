FROM tomcat:7-jre8

ENV JDBC_URL jdbc:mysql://db:3306/oscar_mcmaster?autoReconnect=true&zeroDateTimeBehavior=round&useOldAliasMetadataBehavior=true&jdbcCompliantTruncation=false
ENV JDBC_USER root
ENV JDBC_PASS liyi

