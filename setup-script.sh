#!/bin/sh

# OpenWrt Network Monitoring Setup Script
# This script sets up Prometheus, Grafana, and OpenWRT node exporters

echo "Welcome to the installation of Gesthub v0.1.0"

echo "Installing necessary packages"

opkg update
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano
service dockerd enable
service dockerd start

echo "Starting OpenWrt monitoring setup..."

# Create directory structure
mkdir -p /usr/local/monitoring
cd /usr/local/monitoring
mkdir -p prometheus

# Install OpenWRT-specific exporters
echo "Installing OpenWRT exporters..."
opkg install prometheus-node-exporter-lua \
prometheus-node-exporter-lua-nat_traffic \
prometheus-node-exporter-lua-netstat \
prometheus-node-exporter-lua-openwrt \
prometheus-node-exporter-lua-wifi \
prometheus-node-exporter-lua-wifi_stations

# Download configuration files from GitHub
echo "Downloading configuration files..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/docker-compose.yml -O docker-compose.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/prometheus-config.yml -O prometheus/prometheus.yml

# Enable and start the Lua node exporter service
echo "Enabling OpenWRT node exporter..."
/etc/init.d/prometheus-node-exporter-lua enable
/etc/init.d/prometheus-node-exporter-lua start

# Start Docker containers
echo "Starting Docker containers..."
cd /usr/local/monitoring
docker-compose up -d

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"