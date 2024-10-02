#!/bin/bash

set -ue

source .env

keys_file=$1
docker_image=$2

container_atleta="validator_stagenet"
container_node_exporter="node-exporter"
container_process_exporter="process-exporter"
container_promtail="promtail"
chainspec="./chainspec.json"
rpc_api_endpoint="http://127.0.0.1:9944"
root=$(dirname "$(readlink -f "$0")")
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

start_node_unsafe() {
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
        --bootnodes "$BOOT_NODE_P2P_ADDRESS" \
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
        --rpc-max-connections 10000 \
        --telemetry-url "ws://${TELEMETRY_HOST}:8001/submit 0"
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
        --bootnodes "$BOOT_NODE_P2P_ADDRESS" \
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
        --rpc-max-connections 10000 \
        --telemetry-url "ws://${TELEMETRY_HOST}:8001/submit 0"
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

maybe_cleanup
start_node_unsafe

sleep 30

./add-session-keys.sh "$keys_file" "$validator" "$rpc_api_endpoint" "$container_atleta"

maybe_cleanup
start_node_safe

start_node_exporter
start_process_exporter
start_promtail

echo "Done"