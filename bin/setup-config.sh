#!/usr/bin/env bash

set -x

which yq || snap install yq

if [ -e config/parameters.json ]; then
  read build_args < <(
    jq -r 'to_entries[]|[.key,.value]|join(" ")' config/parameters.json |
    while read k v; do
      echo "--build-arg ${k^^}=$v"
    done | xargs
  )

  jq '.build_args = "'"$build_args"'"' config/parameters.json
else
  echo '{}'
fi |
jq '.project = "'$CIRCLE_PROJECT_REPONAME'"' > .circleci/parameters.json

yq ea '. as $item ireduce({}; . * $item )' .circleci/circleci/common/{headers,executors,parameters}.yml .circleci/circleci/common/{commands,jobs}/*.yml .circleci/circleci/${CIRCLE_PROJECT_REPONAME}.yml > .circleci/project.yml
