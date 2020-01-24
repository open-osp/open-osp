#!/bin/bash

while ! mysqladmin --user=root --password=liyi --host "127.0.0.1" ping --silent &> /dev/null ; do
    echo "Waiting for database connection..."
    sleep 2
done

#./wait-for-it.sh localhost 3306
cd oscar/database/mysql
./createdatabase_bc.sh oscar oscar oscar_mcmaster

echo "Disabling default user expiry..."
mysql -uroot -pliyi oscar_mcmaster << QUERY
update security set date_ExpireDate=DATE_ADD(CURDATE(), INTERVAL 360 MONTH), b_ExpireSet=1 
where user_name='oscardoc';
QUERY