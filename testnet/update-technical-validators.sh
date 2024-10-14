#!/bin/bash

set -u

node_keys_file=$1

if [ $# -ne 1 ]; then
    printf "\033[31m"
    echo "Error: wrong number of arguments"
    printf "\033[0m"
    exit 1
fi

docker compose --env-file "$node_keys_file" up -d --force-recreate bootnode

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate diego

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate pele

sleep 10

docker compose --env-file "$node_keys_file" up -d --force-recreate franz

echo "Done"
