#!/bin/bash

DB=$1

if [ -f "./local.env" ]
then
    source ./local.env
fi

if [ -z "${MYSQL_ROOT_PASSWORD}" ]
then
    MYSQL_ROOT_PASSWORD=liyi
    echo "Generated password not found, using default 'liyi'"
fi

while ! mysqladmin --user=root --password="${MYSQL_ROOT_PASSWORD}" --host "127.0.0.1" ping 
--silent &> /dev/null ; do
    echo "Waiting for database connection..."
    
    sleep 10
done

#./wait-for-it.sh localhost 3306
echo "Populating oscar database"
cd docker/oscar/oscar/database/mysql

if [[ $DB == "ontario" ]]; then
    ./createdatabase_on.sh root "${MYSQL_ROOT_PASSWORD}" oscar
else
    ./createdatabase_bc.sh root "${MYSQL_ROOT_PASSWORD}" oscar
fi

echo "Disabling default user expiry..."
mysql --user=root --password="${MYSQL_ROOT_PASSWORD}" oscar << QUERY
update security set date_ExpireDate=DATE_ADD(CURDATE(), INTERVAL 360 MONTH), b_ExpireSet=1 
where user_name='oscardoc';
GRANT ALL PRIVILEGES ON oscar.* To 'oscar' IDENTIFIED BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
QUERY

