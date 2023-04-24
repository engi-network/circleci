#!/usr/bin/env bash

set -x

which yq || snap install yq

# Setup config parameters
declare -A PARAMS

branches=($(git for-each-ref --points-at HEAD --format '%(refname:lstrip=2)' refs/heads))
tags=($(git for-each-ref --points-at HEAD --format '%(refname:lstrip=2)' refs/tags))

echo "[branches are: ${branches[@]}]"
echo "[tags are: ${tags[@]}]"

PARAMS[build_args]="$build_args"
PARAMS[project]="$CIRCLE_PROJECT_REPONAME"

if [[ "$CIRCLE_TAG" =~ ^v[0-9] ]]; then
  PARAMS[release]=true
  if [[ "$CIRCLE_PROJECT_REPONAME" == "blockchain" ]]; then
    PARAMS[environment]=mainnet
  else
    PARAMS[environment]=production
  fi
  PARAMS[primary_branch]=main
else
  PARAMS[release]=false
  if [[ "$CIRCLE_PROJECT_REPONAME" == "blockchain" ]]; then
    PARAMS[environment]=testnet
  else
    PARAMS[environment]=staging
  fi
  PARAMS[primary_branch]=main
fi

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

eval env -i $(
  for k in ${!PARAMS[@]}; do
    echo "$k=\${PARAMS[$k]}"
  done
) jq 'env' |

sed -r 's/"(false|true)"(,)?$/\1\2/' > .circleci/parameters.json

yq ea '. as $item ireduce({}; . * $item )' .circleci/circleci/common/{headers,executors,parameters}.yml .circleci/circleci/common/{commands,jobs}/*.yml .circleci/circleci/${CIRCLE_PROJECT_REPONAME}.yml .circleci/circleci/common/{build-test-push-workflow,release-workflow.yml}.yml > .circleci/project.yml
