#!/bin/bash

set -uxo

repo_name='oscar'
repo_url=${1:-https://github.com/open-osp/Open-O.git}
repo_branch=${2:-main}
repo_path='docker/oscar/oscar'

echo "Cloning ${repo_name} from ${repo_url} to ${repo_path}"
if [ -d $repo_path ]; then
  echo "$repo_path already exists. Delete the directory if you want to recompile from scratch."
else
  git clone $repo_url $repo_path --branch $repo_branch
fi
