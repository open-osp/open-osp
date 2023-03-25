#!/bin/bash

echo "Starting OpenOSP services."

dc="docker compose  --compatibility"
$dc stop oscar
$dc rm -f oscar

$dc stop expedius
$dc rm -f expedius

$dc up -d db
sleep 5

$dc up -d oscar

$dc up -d expedius

