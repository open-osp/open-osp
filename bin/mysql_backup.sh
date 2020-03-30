#!bin/bash
mkdir -p dump
mysqldump -uoscar -p oscar oscar > dump/
