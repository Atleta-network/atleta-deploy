#!/bin/bash

set -u

node_keys_file=$1

if [ $# -ne 1 ]; then
    printf "\033[31m"
    echo "Error: wrong number of arguments"
    printf "\033[0m"
    exit 1
fi

docker compose --env-file "$node_keys_file" up -d --force-recreate sportchain-bootnode

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate sportchain-diego

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate sportchain-pele

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate boosportchain-franztnode

echo "Done"
