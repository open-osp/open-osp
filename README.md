# Open Oscar Service Provider

This project was developed during the formation of the [OpenOSP](https://openosp.ca) service cooperative. It is a set of open source tools for deploying and running [OSCAR EMR/EHR](https://oscar-emr.com/), an open-source Electronic Medical Record (EMR) for the Canadian family physicians.

This repo was originally based on [scoophealth (UVIC)](https://github.com/scoophealth/oscar-latest-docker)'s fork of [Bell Eapen's](http://nuchange.ca) [Oscar in a Box](https://github.com/dermatologist/oscar-latest-docker).

## Quickstart
  * Install Docker and docker-compose
  * `git clone https://github.com/open-osp/open-osp.git`
  * `cd open-osp`
  * `./openosp setup`
  * Browse to Oscar on http://localhost!
  * Log in with the initial credentials. You will be prompted to change your password upon initial login.
      - Username: oscardoc
      - Password: mac2002
      - 2nd Level Passcode: 1117

## Purpose
The goal of this repo is to provide a hosting-agnostic (Dockerized) toolkit for automated Oscar EMR deployment. We want to centralize Oscar configurations for modern DevOps tools and share [best practices](https://12factor.net/) for modern web application deployment for Oscar. This may help Service Providers who need to automate deployments, Oscar integrators/vendors/developers who need to do testing, and self-hosted users. ie)

* Training (use ./openosp setup)
* Continuous integration of Oscar integrations (use ./openosp setup)
* Testing
* Oscar build toolchains (use openosp build)
* Oscar develpment environments with high [dev/prod parity](https://12factor.net/dev-prod-parity)

## File Layout

`volumes` (gitignored) is intially empty, but will contain any local data that will live in your containers.
`docker` contains data for building docker images to run services.
`bin` holds the scripts that comprise the `./openosp` control command.

## Scope
What does this repo do?

* Builds Oscar from source, for usage locally or to published to DockerHub for use by others.
* Bootstraps a MariaDB database from the same source code as you built from.
* Runs a new containerized Oscar environment including database, in one command (from source or from a tested image).
* Runs drugref locally.

## Design Change

We intend OpenOSP to essentially have 3 operations.

## Oscar Environment Setup and Run
```
./openosp setup
```
ALL configuration options other than specific config files in section 1 below should be set in this ENV file.

If you want a custom Oscar WAR file, you can put it in yout open-osp directory and save it as `oscar.war` and `drugref2.war` for Drugref

This should:
1. Copy all the properties files and docker development yml file.
1. Generate a new local.env file, with unique password for Oscar db, if not already done. (notify user of action taken)
1. Copy all locally editable configs to the volumes/ folder (gitignored), if they dont exist already. Nothing should ever be mounted in a container except from inside this folder and those files are always gitignored copies from a templates/ folder. (notify user)
1. Bootstrap the database if it's missing. (notify user)

Start or Restart current OpenOsp instance
```
./openosp start
```

## Oscar Environment Update

Pull the latest dockerhub image and recreate `tomcat_oscar` container
```
./openosp update
```

## Oscar and Local Development

Build war file and tomcat image only. (in the future, .deb)
```
./openosp build
```

Tag and push to DockerHub
```
openosp publish
```

## Using other Oscar Versions
By default, we are using Oscar 15 when setting up the environment but you could also use other versions of Oscar.

### Oscar 19
To use Oscar 19, on your local.env file, add the following
```
OSCAR_TREEISH=oscar19.1
OSCAR_REPO=git@bitbucket.org:oscaremr/oscar.git
```

Then run `./openosp setup`. This should copy Oscar version 19 to your oscar folder.

We have not fully tested using other versions yet but if you want to use other versions, you can change the `OSCAR_TREEISH` value from any branch in `https://bitbucket.org/oscaremr/oscar/branches/`

## Backups
Backups will create backups for your OpenOsp database and OscarDocuments.

Our backups use AWS so you must install AWS with `apt-get install awscli` then run `aws config`.

You can modify your aws bucket location by changing BACKUP_BUCKET in your `local.env`
```
BACKUP_BUCKET=your/aws/bucket
```
Please also specify your clinic's name with CLINIC_NAME in `local.env`
```
CLINIC_NAME=your_clinic_name
```

You will also need the backups container to exist in your docker-override file. By default it uses the dc.dev.yml file but you can do `cp dc.prod.yml docker-compose.override.yml` to add a backup container.

### Manual Backups
1. Go to your openosp repo, `cd openosp`
2. Run the script `./openosp backup -m`

### Automated Backups
This will run the backup job every midnight unless specified
1. `./openosp backup `

If you want a custom time for your backups, you can add a variable in your local.env

```
CRON_SCHEDULE="*  *  *  *  *"
# this will run every minute. Read about cron scheduling if you are planning to use this.
```


## Clean Up Environment

This is only intended for development purposes.

Delete/reset everything, returning to a fresh clone of openosp. Confirm before deleting configs. Confirm before deleting database. Do not allow this command to run unless the environment variable DEVELOPMENT=1 is set in the local.env file.

```
openosp purge
```

## Prerequisites
* GIT
* Docker
* docker-compose

## Options

Options may be passed in via environment variables on the host.

* Deploy an Oscar fork - `OSCAR_REPO=https://bitbucket.org/dennis_warren/release-ubcpc-15.10.git ./deploy-source.sh` (when you change this variable, delete the `oscar` directory created in the repo root.
* Deploy a specific commit - `OSCAR_TREEISH=<commit, branch or tag id>`
* Deploy a specific WAR (build) you have downloaded in the same folder - `OSCAR_WARFILE`

## Steps
* Builds the lastest Oscar from source (no development environment setup needed).
* Create Docker containers for Tomcat and MariaDB.
* Bootstraps the database using default BC fixtures (easy to change to ON).

To update
```
docker cp oscar-14.0.0-SNAPSHOT.war tomcat_oscar:/usr/local/tomcat/webapps
```

To shell into the tomcat container
```
docker-compose exec tomcat_oscar bash
```

## Docker Image

A Docker image built from the Dockerfile in this repo is published [here](https://hub.docker.com/repository/docker/openosp/open-osp).

## Customize

If you want to customize some pages, you might want to do these before starting your Oscar instance, or if you have already started an instance you can do
```
docker-compose up --build -d nginx
```
to restart both tomcat_oscar and nginx.

### Customizing Login Page
You can customize the login page by adding environment variables to nginx. You can edit the file named 'local.env' and add variables;
```
LOGIN_TEXT=Html text that can <br> be added in the front page
LOGIN_TITLE=Title you want
BUILD_DATE=JAN-10-20
BUILD_NAME=Oscar-build-v12
BUILD_NUMBER=12
```
### Adding Login page Logo
1. You can add a logo by adding a file in the ./static/images directory named OSCAR-LOGO.png (Recommended)
2. You can change CSS for 'login-logo' id

### Custom CSS
We have provided a sample CSS in ./static/css/oscar-custom.css. Feel free to play with this.

### Customizing OpenOsp Properties
1. After starting your container `./start.sh`
2. You should be able to go to `/properties` and login. You can edit credentials on your`local.env` file:
  * By default, it should be openosp and openosp
  * `FLASK_USERNAME`
  * `FLASK_PASSWORD`
3. You should be redirected to a a textarea screen where you can edit your oscar properties file.

## Adding SSL
After deploying, there will be auto-generated ssl keys that are provided but if you have one for that generated you can simply copy them to the `conf` folder and rename them as `ssl.crt` and `ssl.key`.

You can now restart your OpenOsp by doing `./openosp start`

## Host Architecture

[host architecture pdf](!./host-architecture.pdf)

## TODO

For backlog, see the [GitHub issues tab](https://github.com/open-osp/open-osp/issues).

## License

This repository is licensed under the GPL V3

## Thanks (References)
* [Bell Eapen (McMaster U)](http://nuchange.ca) for [Oscar in a Box](https://github.com/dermatologist/oscar-latest-docker)

