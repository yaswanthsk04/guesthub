#!/bin/sh

# OpenWrt Network Monitoring Setup Script
# This script sets up Prometheus, Grafana, and OpenWRT node exporters

echo "Welcome to the installation of Gesthub v0.1.0"

# Enable and restart WiFi
wifi up
wifi reload

# Configure network settings
echo "Configuring LAN IP"
uci set network.lan.ipaddr='192.168.98.1'        # LAN Gateway IP
uci set network.lan.netmask='255.255.254.0'      # Subnet mask to allow 510 IPs
uci commit network
/etc/init.d/network restart

# Configure DHCP settings
echo "Configuring DHCP"
uci set dhcp.lan.start='11'        # DHCP starts from 192.168.98.11
uci set dhcp.lan.limit='500'       # Total IPs: 500 (192.168.98.11 to 192.168.99.254)
uci set dhcp.lan.leasetime='6h'    # Lease time of 6 hours
uci commit dhcp

# Configure static DHCP reservation
echo "Configuring AP IP reservation"
uci add dhcp host
uci set dhcp.@host[-1].mac='5C:A6:E6:D8:CC:B2'   # 5c:a6:e6:d8:cc:b2 mac of tp link
uci set dhcp.@host[-1].ip='192.168.98.2'         # Reserved IP
uci set dhcp.@host[-1].name='AP1 | TP-LINK'    # Optional name
uci commit dhcp
/etc/init.d/dnsmasq restart

echo "Installing necessary packages"
opkg update
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano python3 python3-pip opennds

echo "Starting OpenWrt monitoring services"
service dockerd enable
service dockerd start
service opennds start

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
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/opennds-exporter.py -O opennds-exporter.py

# Setup OpenNDS exporter service
echo "Setting up OpenNDS exporter service..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/opennds-exporter.service -O /etc/init.d/opennds-exporter
chmod +x /etc/init.d/opennds-exporter
/etc/init.d/opennds-exporter enable
/etc/init.d/opennds-exporter start

# Configure and start the Lua node exporter service
echo "Configuring and enabling OpenWRT node exporter..."
uci set prometheus-node-exporter-lua.main.listen_interface='*'
uci commit prometheus-node-exporter-lua
/etc/init.d/prometheus-node-exporter-lua enable
/etc/init.d/prometheus-node-exporter-lua start

# Start Docker containers
echo "Starting Docker containers..."
cd /usr/local/monitoring
docker-compose up -d

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"
