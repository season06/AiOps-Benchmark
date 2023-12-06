#!/bin/bash

[ -z "$1" ] && echo "Backend server IP is empty" && exit 1

[ -z "$2" ] && echo "Database server IP is empty" && exit 1

# Configure the target server to be monitored by Prometheus
cat << EOF | sudo tee -a /etc/prometheus/prometheus.yml

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'backend_node_exporter'
    static_configs:
      - targets: ['$1:9100']

  - job_name: 'jmx_exporter'
    static_configs:
      - targets: ['$1:12345']

  - job_name: 'db_node_exporter'
    static_configs:
      - targets: ['$2:9100']

  - job_name: 'mysqld_exporter'
    static_configs:
      - targets: ['$2:9104']
EOF

sudo systemctl restart prometheus