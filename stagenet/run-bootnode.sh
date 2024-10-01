#!/bin/bash
# Runs a boot node.

set -u

container_name="bootnode"
chainspec="./chainspec.json"

num_of_args=$#
docker_image="$1"

source bootnode-keys.env

check_args() {
    if [ $num_of_args -ne 1 ]; then
        printf "\033[31m"
        echo "Error: wrong number of arguments"
        printf "\033[0m"
        usage
        exit 1
    fi
}

usage() {
    echo "Usage: ./run-bootnode.sh <DOCKER_IMAGE>"
    printf "\t<DOCKER_IMAGE>         node docker image to use\n"
}

check_chainspec() {
    if [ ! -f "$chainspec" ]; then
        printf "\033[31mError: Chainspec file not found.\033[0m\n"
        exit 1
    fi
}

maybe_cleanup() {
    if [ "$(docker ps -q -f name=$container_name)" ]; then
        echo "Stopping existing container..."
        docker stop $container_name
    fi

    if [ "$(docker ps -aq -f status=exited -f name=$container_name)" ]; then
        echo "Removing existing container..."
        docker rm $container_name
    fi
}

start_node() {
    echo "Starting the validator node..."
    docker run -d --name "$container_name" \
        -v "$chainspec":"/chainspec.json" \
        -v "$(pwd)/chain-data":"/chain-data" \
        -p 30333:30333 \
        --platform linux/amd64 \
        --restart always \
        "$docker_image" \
        --chain "/chainspec.json" \
        --name "Atleta Bootnode" \
        --base-path /chain-data \
        --allow-private-ipv4 \
        --validator \
        --listen-addr /ip4/0.0.0.0/tcp/30333 \
        --node-key "$BOOT_NODE_KEY_PRIV" \
        --bootnodes "$BOOT_NODE_P2P_ADDRESS"
}

check_args
check_chainspec
maybe_cleanup
start_node
