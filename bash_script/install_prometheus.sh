#!/bin/bash

# Create a new user and directories
sudo apt update -y
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

# Download and extract
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar vxf prometheus*.tar.gz
rm prometheus*.tar.gz

# Copy the executed and configuration file to system directory
sudo cp -r prometheus-2.43.0.linux-amd64/prometheus /usr/local/bin
sudo cp -r prometheus-2.43.0.linux-amd64/promtool /usr/local/bin
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo cp -r prometheus-2.43.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.43.0.linux-amd64/console_libraries /etc/prometheus
sudo cp -r prometheus-2.43.0.linux-amd64/prometheus.yml /etc/prometheus

# Change the ownership of all folders and files
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Run the Prometheus as a Service
cat << EOF | sudo tee /etc/systemd/system/prometheus.service 
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Start the service
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus

echo "Install Success"