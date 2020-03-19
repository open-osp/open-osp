#!/bin/sh

set -euxo

echo "This deploys a fresh oscar from source."

echo "Compiling OSCAR. This may take some time...."

./build-source.sh
