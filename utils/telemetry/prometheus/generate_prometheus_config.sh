#!/bin/bash

cat <<EOF > prometheus_template.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'devnet'
    static_configs:
      - targets: ['${DEVNET_HOST}:9615', '${DEVNET_HOST}:9100', '${DEVNET_HOST}:9256']
        labels:
          host: '${DEVNET_HOST}'
EOF

for i in {1..16}; do
  host_key="VALIDATOR_${i}_HOST"

  cat <<EOF >> prometheus_template.yml

  - job_name: 'validator_${i}'
    static_configs:
      - targets: ['\${${host_key}}:9615', '\${${host_key}}:9100', '\${${host_key}}:9256']
        labels:
          host: '\${${host_key}}'
EOF
done