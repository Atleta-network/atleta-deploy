#!/bin/sh
set -e

CMD="/app/bin/atleta-node --chain /chainspec.json --base-path /chain-data --node-key $NODE_KEY --name bootnode --state-pruning archive --allow-private-ipv4 --listen-addr /ip4/0.0.0.0/tcp/30333"

for addr in $RESERVED_NODES; do
  CMD="$CMD --reserved-nodes $addr"
done

# Append additional arguments passed via environment variable
CMD="$CMD $NODE_ARGS"

exec $CMD "$@"
