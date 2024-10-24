#!/bin/bash

set -ue

source cleanup.env

root=$(dirname "$(readlink -f "$0")")

maybe_cleanup_containers() {
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

maybe_cleanup

sudo rm -rf /sportchain/atleta/

echo "Done"