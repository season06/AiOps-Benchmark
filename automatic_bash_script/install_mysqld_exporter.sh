#!/bin/bash

# Download and extract
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -xvf mysqld_exporter-0.15.0.linux-amd64.tar.gz
rm mysqld*.tar.gz

# Setup configuraiton
cat << EOF | tee mysqld_exporter-0.15.0.linux-amd64/.my.cnf
[client]
user=prom_exporter
password=password
host=localhost
EOF

echo "Install Success"