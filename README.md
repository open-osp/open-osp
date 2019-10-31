# Dockerized OSCAR EMR (Updated Oct 2019)
OSCAR EMR is an open-source Electronic Medical Record (EMR) for the Canadian family physicians.

## Prerequisites
* GIT
* Docker
* Docker-compose

## How to Use this
```
./install.sh
```

## What the script does
* Checks out master branch from OSCAR repo at bitbucket.
* Compile with maven.
* Create Docker containers.
* Deploy the database and application in the containers.

## Development

To update
```
docker cp oscar-14.0.0-SNAPSHOT.war tomcat_oscar:/usr/local/tomcat/webapps
```

To shell into the tomcat container
```
docker-compose exec tomcat_oscar bash
```

## Forked From (and, thanks to)
* [Bell Eapen (McMaster U)](http://nuchange.ca)

