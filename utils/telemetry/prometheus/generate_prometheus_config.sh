#!/bin/bash

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