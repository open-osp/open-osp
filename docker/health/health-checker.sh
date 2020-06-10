#!/bin/sh

if [ $1 == $2 ]
then
    echo "CORRECT"
else
    echo "Failed connection on $1... Existing"
    exit 1
fi