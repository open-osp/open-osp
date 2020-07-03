#!/bin/sh

if [ $1 == $2 ]
then
    echo "CORRECT"
else
    echo "Failed on http code $1... expected $2"
    exit 1
fi
