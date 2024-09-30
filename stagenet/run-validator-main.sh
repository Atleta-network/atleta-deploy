#!/bin/bash

set -ue

source validator.env

keys_file=$1
node_keys_file=$2

container_atleta="validator_stagenet"
container_node_exporter="node_exporter"
container_process_exporter="process_exporter"
container_promtail="promtail"
chainspec="./chainspec.json"
rpc_api_endpoint="http://127.0.0.1:9944"
root=$(dirname "$(readlink -f "$0")")
DOCKER_IMAGE="atletanetwork/atleta-node:mainnet-latest"
validator="VALIDATOR${INDEX}_"

if [ $# -ne 2 ]; then
    printf "\033[31m"
    echo "Error: wrong number of arguments"
    printf "\033[0m"
    exit 1
fi

check_chainspec() {
    if [ ! -f "$chainspec" ]; then
        printf "\033[31mError: Chainspec file not found.\033[0m\n"
        exit 1
    fi
}

cleanup_all() {
    containers=("$container_atleta" "$container_node_exporter" "$container_process_exporter" "$container_promtail")

    for container in "${containers[@]}"; do
        if [ "$(docker ps -aq -f name="$container")" ]; then
            echo "Stopping and removing existing container $container..."
            docker stop "$container"
            docker rm "$container"
        else
            echo "Container $container not found, skipping..."
        fi
    done
}

cleanup_node() {
    container="$1"

    if [ "$(docker ps -aq -f name="$container")" ]; then
        echo "Stopping and removing existing container $container..."
        docker stop "$container"
        docker rm "$container"
    else
        echo "Container $container not found, skipping..."
    fi
}


start_node_unsafe() {
    echo "Starting the validator node..."
    docker pull "$DOCKER_IMAGE"
    docker run -d --name "$container_atleta" \
        -v "$chainspec":"/chainspec.json" \
        -v "${root}/chain-data":"/chain-data" \
        -p 30333:30333 \
        -p 9944:9944 \
        -p 9615:9615 \
        --platform linux/amd64 \
        "$DOCKER_IMAGE" \
        --validator \
        --name $validator \
        --chain "/chainspec.json" \
        --name $container_atleta \
        --bootnodes $BOOT_NODE_KEY_PUB \
        --base-path /chain-data \
        --rpc-port 9944 \
        --rpc-methods=unsafe \
        --unsafe-rpc-external \
        --prometheus-external \
        --prometheus-port 9615 \
        --rpc-cors all \
        --allow-private-ipv4 \
        --listen-addr /ip4/0.0.0.0/tcp/30333 \
        --state-pruning archive \
        --enable-log-reloading \
        --max-runtime-instances 32 \
        --rpc-max-connections 10000
}


start_node_safe() {
    echo "Starting the validator node..."
    docker pull "$DOCKER_IMAGE"
    docker run -d --name "$container_atleta" \
        -v "$chainspec":"/chainspec.json" \
        -v "${root}/chain-data":"/chain-data" \
        -p 30333:30333 \
        -p 9944:9944 \
        -p 9615:9615 \
        --platform linux/amd64 \
        "$DOCKER_IMAGE" \
        --validator \
        --chain "/chainspec.json" \
        --node-key $VALIDATOR_KEY \
        --bootnodes $BOOT_NODE_KEY_PUB \
        --base-path /chain-data \
        --rpc-port 9944 \
        --rpc-methods=safe \
        --unsafe-rpc-external \
        --prometheus-external \
        --prometheus-port 9615 \
        --rpc-cors all \
        --allow-private-ipv4 \
        --listen-addr /ip4/0.0.0.0/tcp/30333 \
        --state-pruning archive \
        --enable-log-reloading \
        --max-runtime-instances 32 \
        --rpc-max-connections 10000
}

cleanup_all
start_node_unsafe

sleep 30

./add-session-keys.sh "$keys_file" "$validator" "http://127.0.0.1:9944" "$container_atleta"

cleanup_node"$container_atleta"
start_node_safe


echo "Done"
