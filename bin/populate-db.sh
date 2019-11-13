#!/bin/bash

while ! mysqladmin --user=root --password=liyi --host "127.0.0.1" ping --silent &> /dev/null ; do
    echo "Waiting for database connection..."
    sleep 2
done

#./wait-for-it.sh localhost 3306
cd oscar/database/mysql
./createdatabase_bc.sh oscar oscar oscar_mcmaster

