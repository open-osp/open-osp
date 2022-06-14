#! /bin/bash

echo "Setting up the Fax server"
#!/bin/bash

source ./local.env

echo "Setting Fax WS passwords..."

tomcatUser=faxws
tomcatPassword=$FAXWS_TOMCAT_PASSWORD

# 8. Migrate mvn flyway:migrate
## cannot use on older MySQL databases. Must be 5.7 and up or this command will fail.
docker-compose up -d db

sleep 3

docker-compose up -d faxws

sleep 3

docker-compose exec db mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD -e "drop database if exists OscarFax"
docker-compose exec db mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD -e "create database OscarFax"

# Run migrations
# [cvo] use sql bootstrap instead for now.
#docker-compose exec faxws bash -c "cd /usr/local/tomcat/webapps/faxWs/META-INF/maven/oscarFax/FaxWs && mvn flyway:migrate -Dflyway.user=root -Dflyway.password=tzcbU/u87wM= -Dflyway.url=jdbc:mysql://db/oscarFax"
docker-compose cp faxws:/create_database.sql _bootstrap.sql

docker-compose exec db bash -c "mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD OscarFax < _bootstrap.sql"
rm _bootstrap.sql

echo "Setting authentication database..."
docker-compose exec db mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD OscarFax -e "insert into users Values('$tomcatUser','$tomcatPassword')"
docker-compose exec db mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD OscarFax -e "insert into user_roles Values('$tomcatUser','user')"


