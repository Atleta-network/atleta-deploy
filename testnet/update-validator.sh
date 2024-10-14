#!/bin/bash
# Runs a validator node:
#
# 1. Starts an archive node;
# 2. Adds session keys;

# expects files in the same directory:
# - config.env
# - chainspec.json

# config.env should be created and uploaded by CD worker, it should contain:

# BOOTNODE_ADDRESS=<node address in libp2p form>
# PRIVATE_KEY=<key in hex>
# DOCKER_IMAGE=<image name>
# PRIVATE_NODE_KEY=<key>
# PUBLIC_NODE_KEY=<key>

set -u

source ./config.env

container_atleta="honest_worker"
container_node_exporter="node_exporter"
container_process_exporter="process_exporter"
container_promtail="promtail"
chainspec="./chainspec.json"
rpc_api_endpoint="http://127.0.0.1:9944"
root=$(dirname "$(readlink -f "$0")")

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
    docker pull "$DOCKER_IMAGE"
    docker run -d --name "$container_atleta" \
        -v "$chainspec":"/chainspec.json" \
        -v "$(pwd)/chain-data":"/chain-data" \
        -p 30333:30333 \
        -p 9944:9944 \
        -p 9615:9615 \
        --platform linux/amd64 \
        --restart always \
        "$DOCKER_IMAGE" \
        --chain "/chainspec.json" \
        --validator \
        --name "Atleta_Validator_14" \
        --node-key "$PRIVATE_NODE_KEY" \
        --bootnodes "$BOOTNODE_ADDRESS" \
        --base-path /chain-data \
        --rpc-port 9944 \
        --unsafe-rpc-external \
        --rpc-methods=safe \
        --telemetry-url "ws://${TELEMETRY_HOST}:8001/submit 1" \
	    --prometheus-external \
        --rpc-cors all \
        --allow-private-ipv4 \
        --listen-addr /ip4/0.0.0.0/tcp/30333 \
        --state-pruning archive \
        --enable-log-reloading \
        --max-runtime-instances 32 \
        --rpc-max-connections 10000
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

wait_availability() {
    local retry_count=0
    local max_retries=30
    local retry_interval=7

    while [ $retry_count -lt $max_retries ]; do

        # Use curl to test the connection without making an actual request and Check the exit status of curl
        if curl --connect-timeout 5 "$rpc_api_endpoint" 2>/dev/null; then
            echo "Connected to $rpc_api_endpoint"
            break
        else
            echo "$rpc_api_endpoint is not available. Retrying in $retry_interval seconds..." 
            sleep "$retry_interval"
            ((retry_count++))
        fi
    done
    
    if [ "$retry_count" -eq "$max_retries" ]; then
        printf "\033[31mError: Couldn't connect to %s\033[0m\n" "$rpc_api_endpoint"
        kill $$
    fi
}

check_chainspec
maybe_cleanup
start_node
start_node_exporter
start_process_exporter
start_promtail
wait_availability

# the rest is done via js

# FIXME: it doesn't work via CD.
# I don't know why yet, but the script always fails via CD, while working when
# you run it manually on the server.

# npm i 
# npm run set_keys
# npm run validate
