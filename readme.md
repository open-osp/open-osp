# Dockerized OSCAR EMR
OSCAR EMR is an open-source Electronic Medical Record (EMR) for the Canadian family physicians.

This is a script to deploy master branch from OSCAR repository on a docker container. This is for OSCAR developers. If you want just to use OSCAR try my [vagrant script](http://nuchange.ca/2015/09/installing-oscar-emr-and-openmrs-ehr-in-your-laptop.html).

## Prerequisites
* GIT
* Maven
* Docker
* Docker-compose
* USE THE LATEST DATABASE DUMP. You may have to add all update sql too.  

## How to Use this
* Just clone this repo, add database dump (Oscar15ON.sql) to dbdump and ./install.sh
* Access Tomcat at http://localhost:8091/ (oscar/oscar) and start oscar_mcmaster service.
* Access oscar at http://localhost:8091/oscar_mcmaster/
* You can setup your development environment such as IntelliJ to auto-deploy into the container.

## What the script does
* Checks out master branch from OSCAR repo at bitbucket.
* Compile with maven.
* Create Docker containers.
* Deploy the database and application in the containers.

## Author
* [Bell Eapen (McMaster U)](http://nuchange.ca)
