#!/bin/bash

docker-compose build oscar
docker tag open-osp_oscar openosp-oscar:latest
docker push openosp-oscar:latest

docker-compose build expedius
docker tag open-osp_expedius colcamex-expedius:latest
docker push colcamex-expedius:latest