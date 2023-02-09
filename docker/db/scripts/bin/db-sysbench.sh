#!/bin/bash

# Run this in the db service. A good Trx/S is around 1000 or more.

sysbench --db-driver=mysql --mysql-user=root --mysql-password=${MYSQL_ROOT_PASSWORD}  --mysql-db=oscar --range_size=100   --table_size=10000 --tables=2 --threads=1 --events=0 --time=60   --rand-type=uniform /usr/share/sysbench/oltp_read_only.lua prepare
sysbench --db-driver=mysql --mysql-user=root --mysql-password=${MYSQL_ROOT_PASSWORD}  --mysql-db=oscar --range_size=100   --table_size=10000 --tables=2 --threads=1 --events=0 --time=60   --rand-type=uniform /usr/share/sysbench/oltp_read_only.lua run
