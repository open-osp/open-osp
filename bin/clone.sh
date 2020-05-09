#!/bin/bash


set -uxo

repo=${1:-https://countable@bitbucket.org/openoscar/oscar.git}
branch=${2:-release/Oscar-BC-15}

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone $repo oscar
    cd oscar
    git checkout $branch
fi
