#!/bin/bash

mysqlcheck -u root -p${MYSQL_ROOT_PASSWORD} --all-databases
mysqlcheck -u root -p${MYSQL_ROOT_PASSWORD} --all-databases -o
mysqlcheck -u root -p${MYSQL_ROOT_PASSWORD} --all-databases --auto-repair
mysqlcheck -u root -p${MYSQL_ROOT_PASSWORD} --all-databases --analyze
