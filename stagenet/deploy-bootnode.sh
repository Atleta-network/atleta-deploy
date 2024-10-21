#!/bin/bash
# Runs a boot node.

set -u

source .env
source bootnode-keys.env

container_atleta="bootnode"
chainspec="./chainspec.json"
container_node_exporter="node-exporter"
container_process_exporter="process-exporter"
container_promtail="promtail"
root=$(dirname "$(readlink -f "$0")")
num_of_args=$#
docker_image=$1

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

start_node() {
    echo "Starting the validator node..."
    docker run -d --name "$container_atleta" \
        -v "$chainspec":"/chainspec.json" \
        -v "$(pwd)/chain-data":"/chain-data" \
        -p 30333:30333 \
        -p 9615:9615 \
        --platform linux/amd64 \
        --restart always \
        "$docker_image" \
        --chain "/chainspec.json" \
        --name "Atleta Bootnode" \
        --base-path /chain-data \
        --allow-private-ipv4 \
        --validator \
        --state-pruning archive \
        --listen-addr /ip4/0.0.0.0/tcp/30333 \
        --node-key "$BOOT_NODE_KEY_PRIV" \
        --bootnodes "$BOOT_NODE_P2P_ADDRESS" \
        --prometheus-external \
        --prometheus-port 9615 \
        --telemetry-url "ws://${TELEMETRY_HOST}:8001/submit 1"
}

start_node_exporter() {

    echo "Starting the node_exporter..."
    docker pull prom/node-exporter:latest
    docker run -d --name "$container_node_exporter" \
        -p 9100:9100 \
        prom/node-exporter:latest
}

start_process_exporter() {

    echo "Starting the process_exporter..."

    docker pull ncabatoff/process-exporter:latest
    docker run -d --name "$container_process_exporter" \
        -v "${root}/process-exporter/process-exporter.yml:/config/process-exporter.yml:ro" \
        -v /proc:/host/proc:ro \
        -p 9256:9256 \
        ncabatoff/process-exporter:latest \
        --config.path=/config/process-exporter.yml \
        --procfs=/host/proc
}

start_promtail() {

    echo "Starting the promtail..."
    docker pull grafana/promtail:latest
    docker run -d --name "$container_promtail" \
         -p 9080:9080 \
         -v "${root}/promtail/promtail-config.yml:/etc/config/promtail-config.yml" \
         -v /var/log:/var/log \
         -v /var/run/docker.sock:/var/run/docker.sock \
         grafana/promtail:latest \
         -config.file=/etc/config/promtail-config.yml
}

check_args
check_chainspec
maybe_cleanup
start_node

start_node_exporter
start_process_exporter
start_promtail

echo "Done"
