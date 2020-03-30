#!/bin/bash


set -uxo

branch=${OSCAR_TREEISH:-release/Oscar-BC-15}
repo=${OSCAR_REPO:-https://countable@bitbucket.org/openoscar/oscar.git}

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone $repo oscar
    cd oscar
    git checkout $branch
fi