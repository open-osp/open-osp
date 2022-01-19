#!/bin/bash

perl -pi.bak -e "s/com.mysql.jdbc.Driver/com.mysql.cj.jdbc.Driver/g" volumes/oscar.properties

#change HTTPS_PROTOCOL=TLSv1  to HTTPS_PROTOCOL=TLSv1.2
perl -pi.bak -e "s/TLSv1/TLSv1.2/g" volumes/expedius/expedius.properties

#change VERSION=Version 4.12.19 to VERSION=Version 4.12.21
perl -pi.bak -e "s/4.12.19/4.12.21/g" volumes/expedius/expedius.properties

