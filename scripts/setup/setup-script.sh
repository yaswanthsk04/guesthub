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

# Create main directories
mkdir -p update-system docker/prometheus exporters updates backups state
chmod 755 update-system docker docker/prometheus exporters updates backups state

# Set proper ownership
chown -R root:root /usr/local/monitoring

# Create initial state file
echo "0" > state/last_update
chmod 644 state/last_update

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
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/config/docker-compose.yml -O docker/docker-compose.yml
chmod 644 docker/docker-compose.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/config/prometheus-config.yml -O docker/prometheus/prometheus-config.yml
chmod 644 docker/prometheus/prometheus-config.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/services/opennds-exporter.py -O exporters/opennds-exporter.py
chmod 755 exporters/opennds-exporter.py

# Setup OpenNDS exporter service
echo "Setting up OpenNDS exporter service..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/services/opennds-exporter.service -O /etc/init.d/opennds-exporter
chmod +x /usr/local/monitoring/exporters/opennds-exporter.py
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
cd /usr/local/monitoring/docker
docker network create monitoring_network || true  # Create if doesn't exist
docker-compose up -d

# Show status
echo "Verifying containers are running..."
docker-compose ps

echo "Container restart policy set to 'always' - will auto-start after reboot"

# Install and configure update system
echo "Setting up automatic update system..."

# Download update system components with proper permissions
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/update/update-checker.py -O /usr/local/monitoring/update-system/update-checker.py
chmod 755 /usr/local/monitoring/update-system/update-checker.py

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/update/update-checker.service -O /etc/init.d/update-checker
chmod 755 /etc/init.d/update-checker

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/update/update-executor.sh -O /usr/local/monitoring/update-system/executor.sh
chmod 755 /usr/local/monitoring/update-system/executor.sh


# Start update checker service
/etc/init.d/update-checker enable
/etc/init.d/update-checker start

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"
echo "Automatic updates are enabled and will check hourly"
