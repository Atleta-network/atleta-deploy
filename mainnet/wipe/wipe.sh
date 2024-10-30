#!/bin/bash

set -ue

source cleanup.env

: "${container_atleta:?Variable container_atleta is required but not set}"
: "${container_process_exporter:=}" 
: "${container_promtail:=}"

maybe_cleanup_containers() {
    containers=("$container_atleta" "$container_process_exporter" "$container_promtail")

    for container in "${containers[@]}"; do
        if [ -n "$container" ] && [ "$(docker ps -aq -f name="$container")" ]; then
            echo "Stopping and removing existing container $container..."
            docker rm -f "$container" || echo "Failed to remove container $container"
        else
            echo "Container $container not found or name is empty, skipping..."
        fi
    done
}

maybe_cleanup_containers

sudo rm -rf /mnt/sportchain/atleta/

echo "Done"
