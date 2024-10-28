#!/bin/bash

set -ue

source cleanup.env

: "${container_atleta:?Variable container_atleta is required but not set}"
: "${container_process_exporter:=}" 
: "${container_promtail:=}"

maybe_cleanup_containers() {

    if [ -z "$(docker ps -aq -f name="$container_atleta")" ]; then
        echo "Required container $container_atleta not found. Exiting..."
        exit 1
    fi

    containers=("$container_atleta" "$container_process_exporter" "$container_promtail")

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

maybe_cleanup_containers

sudo rm -rf /sportchain/atleta/

echo "Done"