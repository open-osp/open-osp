#! /bin/bash

echo "Setting up the Fax server"

## 3. Clone
git clone https://dennis_warren@bitbucket.org/openoscar/faxws.git

## 4. Checkout
git checkout origin/release

# 5. current MySQL pass and username
echo "Setting Fax WS database passwords... "

read -p "MySQL database username? " username
read -p "MySQL database password? " passwd

perl -pi -e "s/{user}/$username/"  ./src/main/webapp/META-INF/context.xml
perl -pi -e "s/{passwd}/$passwd/"  ./src/main/webapp/META-INF/context.xml

# 6. new FaxWs pass and username
read -p "What username do you want to log in as in tomcat? " tomcatUser
read -p "What password do you want for $tomcatUser? " tomcatPassword

# 7. build FaxWs mvn clean package
echo "Build FaxWs with Maven..."

mvn clean
mvn package

# 8. Migrate mvn flyway:migrate
## cannot use on older MySQL databases. Must be 5.7 and up or this command will fail.
mvn flyway:migrate -Dflyway.user=$username -Dflyway.password=$passwd

# 9. Add pass and username to db
echo "Setting authentication database..."

mysql -u$username -p$passwd oscarFax -e "insert into users Values('$tomcatUser','$tomcatPassword')"
mysql -u$username -p$passwd oscarFax -e "insert into user_roles Values('$tomcatUser','user')"

# 10. Move WAR and JDBC Driver to Tomcat

# c. move the WAR file. 

mv -f ./target/FaxWs*SNAPSHOT.war docker/faxws/

# d. move the JDBC Jar
cp ./target/FaxWs-1.0.0-SNAPSHOT/WEB-INF/lib/mysql-connector-java*.jar docker/faxws/

