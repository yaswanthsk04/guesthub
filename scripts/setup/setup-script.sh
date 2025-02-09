#!/bin/sh

# OpenWrt Network Monitoring Setup Script
echo "Welcome to the installation of Gesthub v0.1.0"

# Enable and restart WiFi
uci set wireless.radio0.disabled=0
wifi reload

echo "Installing necessary packages"
opkg update
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano python3 python3-pip opennds
pip install prometheus_client requests
echo "Starting OpenWrt monitoring services"
service dockerd enable
service dockerd start
service opennds enable
service opennds start

echo "Starting OpenWrt monitoring setup..."
# Create directory structure with proper permissions
echo "Creating directory structure..."
mkdir -p /usr/local/monitoring
chmod 755 /usr/local/monitoring
cd /usr/local/monitoring
mkdir -p prometheus
chmod 755 prometheus
mkdir -p updates
chmod 755 updates
mkdir -p backups
chmod 755 backups

# Set proper ownership
chown -R root:root /usr/local/monitoring

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
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/config/docker-compose.yml -O docker-compose.yml
chmod 644 docker-compose.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/config/prometheus-config.yml -O prometheus/prometheus.yml
chmod 644 prometheus/prometheus.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/services/opennds-exporter.py -O opennds-exporter.py
chmod 755 opennds-exporter.py

# Setup OpenNDS exporter service
echo "Setting up OpenNDS exporter service..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/services/opennds-exporter.service -O /etc/init.d/opennds-exporter
chmod +x /usr/local/monitoring/opennds-exporter.py
chmod +x /etc/init.d/opennds-exporter
/etc/init.d/opennds-exporter enable
/etc/init.d/opennds-exporter start

# Configure and start the Lua node exporter service
echo "Configuring and enabling OpenWRT node exporter..."
uci set prometheus-node-exporter-lua.main.listen_interface='*'
uci commit prometheus-node-exporter-lua
/etc/init.d/prometheus-node-exporter-lua enable
/etc/init.d/prometheus-node-exporter-lua start

# Setup Docker containers service
echo "Setting up Docker containers service..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/services/monitoring-containers.service -O /etc/init.d/monitoring-containers
chmod +x /etc/init.d/monitoring-containers
/etc/init.d/monitoring-containers enable
/etc/init.d/monitoring-containers start

# Install and configure update system
echo "Setting up automatic update system..."

# Download update system components with proper permissions
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/scripts/update/update-checker.py -O /usr/local/monitoring/update-checker.py
chmod 755 /usr/local/monitoring/update-checker.py

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/scripts/update/update-checker.service -O /etc/init.d/update-checker
chmod 755 /etc/init.d/update-checker

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/scripts/update/update-executor.sh -O /usr/local/monitoring/update-executor.sh
chmod 755 /usr/local/monitoring/update-executor.sh

# Create initial last_update file with proper permissions
echo "0" > /usr/local/monitoring/last_update
chmod 644 /usr/local/monitoring/last_update

# Create initial last_update file
echo "0" > /usr/local/monitoring/last_update

/etc/init.d/update-checker enable
/etc/init.d/update-checker start

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"
echo "Automatic updates are enabled and will check hourly"
