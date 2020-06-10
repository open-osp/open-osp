#!/bin/sh

# Builds all the docker images.

set -exo

COMMAND=$1
WARFILE=$2

case "${COMMAND}" in
    oscar)
        OSCAR_OUTPUT=docker/oscar
        if [ -z "$WARFILE" ]
        then
            echo "Compiling OSCAR. This may take some time...."
            docker-compose -f docker-compose.build.yml run builder ./bin/build-oscar.sh
            mv $OSCAR_OUTPUT/oscar/target/oscar-*-SNAPSHOT.war $OSCAR_OUTPUT/oscar.war
        else
            mkdir -p $OSCAR_OUTPUT
            cp $WARFILE $OSCAR_OUTPUT/oscar.war
        fi

        export DRUGREF_WAR=${DRUGREF_WAR:-"http://bool.countable.ca/drugref2.war"}

        # Download drugref if we need it.
        if [ ! -f $OSCAR_OUTPUT/drugref2.war ]; then
          # Latest OscarBC as of Nov 13 2019.
          docker run -v $(pwd):/code/ busybox sh -c "cd /code/ && wget $DRUGREF_WAR -O $OSCAR_OUTPUT/drugref2.war"
        fi

        echo "Building Oscar Docker Image"
        docker-compose build oscar
        ;;
    expedius)

        ;;
    faxws)
        echo "Compilnig FaxWS"
        docker-compose -f docker-compose.build.yml run builder ./bin/build-faxws.sh

        echo "Building FaxWs Docker Image"
        docker-compose build faxws
        ;;
esac


