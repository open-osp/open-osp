#!/bin/bash

repo_name='faxws'
repo_url='https://bitbucket.org/openoscar/faxws.git'
repo_branch='master'
repo_path='docker/faxws/faxws'

echo "Cloning ${repo_name} from ${repo_url} to ${repo_path}"
if [ -d $repo_path ]; then
  echo "$repo_path already exists. Delete the directory if you want to recompile from scratch."
else
  git clone $repo_url $repo_path --branch $repo_branch
fi

cd $repo_path

echo "Remove context xml so we can replace it after WAR extraction."
rm -f src/main/webapp/META-INF/context.xml

echo "Build FaxWs with Maven..."

if [[ "${TEST_DURING_BUILD:-}" ]]; then
  mvn clean package
else
  mvn -Dcheckstyle.skip -Dmaven.test.skip=true clean package
fi
