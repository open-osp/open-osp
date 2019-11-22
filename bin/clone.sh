#!/bin/bash


set -uxo

branch=${OSCAR_TREEISH:-master}
repo=${OSCAR_REPO:-https://bitbucket.org/oscaremr/oscar.git}

echo "Cloning oscar from bitbucket"
if [ -d "./oscar" ]; then
    echo "already cloned"
else
    git clone $repo oscar
    cd oscar
    git checkout $branch
fi


