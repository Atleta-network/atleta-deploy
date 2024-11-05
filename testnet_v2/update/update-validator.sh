#!/bin/bash

set -ue

source .env

docker_image=$1

container_process_exporter="process-exporter"
container_promtail="promtail"
chainspec="./chainspec.json"
root=$(dirname "$(readlink -f "$0")")
validator="VALIDATOR${INDEX}_"

if [ $# -ne 1 ]; then
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

maybe_cleanup() {
    containers=("$container_atleta")

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

start_node_safe() {
    echo "Starting the validator node..."
    docker pull "$docker_image"
    docker run -d --name "$container_atleta" \
        -v "$chainspec":"/chainspec.json" \
        -v "${root}/chain-data":"/chain-data" \
        -p 30333:30333 \
        -p 9944:9944 \
        -p 9615:9615 \
        --platform linux/amd64 \
        "$docker_image" \
        --validator \
        --chain "/chainspec.json" \
        --node-key "$VALIDATOR_KEY" \
        --name "$validator" \
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

start_process_exporter() {
    if [ ! "$(docker ps -q -f name=$container_process_exporter)" ]; then
        echo "Starting the process_exporter..."
        docker pull ncabatoff/process-exporter:latest
        docker run -d --name "$container_process_exporter" \
            -v "${root}/process-exporter/process-exporter.yml:/config/process-exporter.yml:ro" \
            -v /proc:/host/proc:ro \
            -p 9256:9256 \
            ncabatoff/process-exporter:latest \
            --config.path=/config/process-exporter.yml \
            --procfs=/host/proc
    else
        echo "Process_exporter is already running."
    fi
}

start_promtail() {
    if [ ! "$(docker ps -q -f name=$container_promtail)" ]; then
        echo "Starting the promtail..."
        docker pull grafana/promtail:latest
        docker run -d --name "$container_promtail" \
            -p 9080:9080 \
            -v "${root}/promtail/promtail-config.yml:/etc/config/promtail-config.yml" \
            -v /var/log:/var/log \
            -v /var/run/docker.sock:/var/run/docker.sock \
            grafana/promtail:latest \
            -config.file=/etc/config/promtail-config.yml
    else
        echo "Promtail is already running."
    fi
}

maybe_cleanup

start_node_safe

start_process_exporter
start_promtail

echo "Done"