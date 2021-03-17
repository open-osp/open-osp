# Open OSP

This project was developed during the formation of the [Open OSP](https://openosp.ca) Service Cooperative. It is a set of open source software tools for deploying and running the Open Source Electronic Medical Record (OSCAR EMR) for Canadian family physicians.

This repo was originally based on [scoophealth (UVIC)](https://github.com/scoophealth/oscar-latest-docker)'s fork of [Bell Eapen's](http://nuchange.ca) [Oscar in a Box](https://github.com/dermatologist/oscar-latest-docker).

## Quickstart
  * Install Docker and docker-compose
  * `git clone https://github.com/open-osp/open-osp.git` (master is the stable branch to use)
  * `cd open-osp`
  * `./openosp setup`
  * if you need a database, `./openosp bootstrap`
  * `./openosp start`
  * Browse to OSCAR EMR on http://localhost:8080/oscar!

  * Log in with the initial credentials. You will be prompted to change your password upon initial login.
      - Username: oscardoc
      - Password: mac2002
      - 2nd Level Passcode: 1117


## Purpose
The goal of this repo is to provide a hosting-agnostic (Dockerized) toolkit for automated OSCAR EMR deployment. We want to centralize OSCAR configurations for modern DevOps tools and share [best practices](https://12factor.net/) for modern web application deployment for OSCAR. This may help potential service providers who need to automate deployments, OSCAR integrators/vendors/developers who need to do testing, and self-hosted users. ie)

* Training (use ./openosp setup)
* Continuous integration of Oscar integrations (use ./openosp setup)
* Testing
* OSCAR build toolchains (use openosp build)
* OSCAR develpment environments with high [dev/prod parity](https://12factor.net/dev-prod-parity)

## File Layout

`volumes` (gitignored) is intially empty, but will contain any local data that will live in your containers.
`docker` contains data for building docker images to run services.
`bin` holds the scripts that comprise the `./openosp` control command.

## Scope
What does this repo do?

* Builds OSCAR from source, for usage locally or to published to DockerHub for use by others.
* Bootstraps a MariaDB database from the same source code as you built from.
* Runs a new containerized OSCAR environment including database, in one command (from source or from a tested image).
* Runs DrugRef locally.
* Runs Expedius
* Runs FaxWS

## OSCAR Environment Setup and Run
```
./openosp setup
```
ALL configuration options other than specific config files in section 1 below should be set in this ENV file, `local.env`

This should:
1. Copy all the properties files and docker development yml file.
1. Generate a new local.env file, with unique password for OSCAR db, if not already done. (notify user of action taken)
1. Copy all locally editable configs to the volumes/ folder (gitignored), if they dont exist already. Nothing should ever be mounted in a container except from inside this folder and those files are always gitignored copies from a templates/ folder. (notify user)

To create a database: ```
./openosp bootstrap
```

Start or Restart current OpenOsp instance
```
./openosp start
```

## OSCAR Environment Update

The steps to update a clinic:


Suppose the image tag you want to update to is `2020.11.06`

1. Once per host, do `docker pull 2020.11.06`
1. Change directory to the clinic in question.
1. Set the image version tag in docker-compose.override.yml , in the oscar service to the desired version. Do not use latest in production for this, if you want to prioritize stability, because it is difficult to track what version is actually being referred to.

ie.
```
services:
  oscar:
    image: openosp/open-osp:2020.11.06
```

1. Run `git pull origin master` to ensure environment scripts are up to date.
1. Run `openosp start`

## OSCAR and Local Development

Build war file and tomcat image only. (in the future, .deb)
```
./openosp build oscar
```

## Using other OSCAR Versions
By default, the most current release version of Open OSCAR is used when setting up the environment. It is possible to use other versions of Oscar.

If you want to use other versions, you can change the `OSCAR_TREEISH` value from any branch in 
`https://bitbucket.org/oscaremr/oscar/branches/`

## OSCAR Devlopment Branch
To use the OSCAR Development branch, on your local.env file, add the following
```
OSCAR_TREEISH=oscarDev
OSCAR_REPO=git@bitbucket.org:oscaremr/oscar.git
```

## OSCAR Backups
Backup methods will create backups for the OSCAR EMR database and OscarDocuments.

### Off Site Backups
Off Site backups can be configured to use AWS S3 Buckets. First set up a AWS S3 bucket and an IAM user to authenticate. Be sure to write down the IAM access key, secret key, and bucket name information.

1. Install AWS on the OSCAR Docker server
```
apt-get install awscli
```
2. Then run the AWS configuration script
```
aws configure
```
3. Set the BACKUP_BUCKET variable in the Docker `local.env` file to the name of the AWS bucket. Example:
```
BACKUP_BUCKET="clinic-backupname"
```
4. Also specify your clinic's name (as a slug) with CLINIC_NAME in the Docker `local.env`
```
CLINIC_NAME=your_clinic_name
```
5. Run the backup process 
```
./openosp backup -m
```
October 2020: This process is not Dockerized and automated at this time. However the manual script `./openosp backup -m` could be set to run on a chron job.

HDC exporting can be done as: import the encryption key `gpg --import key.pgp`, then run `openosp backup -m --hdc`

### Manual Backups
To run a manual backup for both local and remote (if avaialble)

1. Go to your openosp repo, `cd openosp`
2. Run the script `./openosp backup -m`

### Automated Backups
(not supported yet, but you can call manual backups from a cronjob on your host)

## Truncate and Purge Environment
WARNING: This will delete ALL data permanently!

Delete/reset everything, returning to a fresh clone of openosp. Confirm before deleting configs. Confirm before deleting database. Do not allow this command to run unless the environment variable DEVELOPMENT=1 is set in the local.env file.

```
openosp purge
```

## MariaDB Configuration

```
touch volumes/my.cnf
```

In your environment, override the volume in the `db:` service in `docker-compose.override.yml`
```
  db:
    volumes:
      - ./volumes/my.cnf:/etc/mysql/conf.d/my.cnf

```
Reload the database container
```
docker-compose up -d db
```
## Log Access
Logs are no longer found in the usual OSCAR server locations: /var/lib/logs/catalina.out, /var/log/mysql.error, etc... Logs are managed and redirected through each Docker container's stdout. Up to 3 days of history is available. 

### OSCAR (catalina.out) Logs
To tail OSCAR logs

```
docker-compose ps
```
note the Docker container name for the OSCAR container then

```
docker logs --tail=3000 -f oscar-docker-containername
```
### MariaDB Error Logs
To tail MariaDB logs

```
docker-compose ps
```
note the Docker container name for the DB container then

```
docker logs --tail=3000 -f db-docker-containername
```
### Dump All Log History
To dump all the log history for any container: 

```
docker-compose ps
```
note the Docker container name for the logs to be dumped

```
docker logs docker-containername > allhistory.log
```

or to dump a continuous log

```
docker logs --tail -f docker-containername &> continuoushistory.log
```

### Change Log Verbosity
The log properties override files are found in ./volumes  Log properties for MariaDB are overriden in the my.sql file (see above section about MariaDB Configuration)

Caution: it is unknown at this time if these properties files actualy override.

## Performance Profiling

To enable melody performance profiling, run the following script.

```
./bin/setup-melody.sh
```

and visit http://localhost:8080

## Prerequisites
* GIT
* Docker
* docker-compose

## Docker Image

A Docker image built from the Dockerfile in this repo is published [here](https://hub.docker.com/repository/docker/openosp/open-osp).

## Host Architecture

[host architecture pdf](!./host-architecture.pdf)

## Contributing

Merge general work to `develop`, and bugfixes into `master`. We will occasionally "release" `develop` into `master` by testing and merging it in.

For backlog, see the [GitHub issues tab](https://github.com/open-osp/open-osp/issues).

## Design Patterns / Guidelines

1. Run pre-made docker images in production.
1. Define as few dynamic configs as possible at runtime.
1. Minimize the amount of setup/automation/scripting required to deploy a new environment.
1. Conversely, do as much as possible at build time (in docker images pre-baked).
1. For a new environment, set dynamic secrets automatically, once at setup.

## License

This repository is licensed under the GPL V3

## Thanks (References)
* [Bell Eapen (McMaster U)](http://nuchange.ca) for [Oscar in a Box](https://github.com/dermatologist/oscar-latest-docker), which this repository was originally forked from.


