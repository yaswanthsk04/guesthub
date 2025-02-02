#!/bin/sh

# OpenWrt Network Monitoring Setup Script
# This script sets up Prometheus, Grafana, and node_exporter for OpenWrt network monitoring

echo "Welcome to the installation of Gesthub v0.1.0"

echo "Installing necessary packages"

opkg update
opkg install 
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano
service dockerd enable
service dockerd start

echo "Starting OpenWrt monitoring setup..."

# Create directory structure
mkdir -p /usr/local/monitoring
cd /usr/local/monitoring
mkdir -p prometheus
mkdir -p /var/lib/node_exporter/textfile_collector
mkdir -p /usr/local/bin

# Install required packages
echo "Installing required packages..."
opkg install curl wget conntrack node-exporter

wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-arm64.tar.gz
tar xvf node_exporter-1.7.0.linux-arm64.tar.gz
cp node_exporter-1.7.0.linux-arm64/node_exporter /usr/bin/

# Download configuration files from GitHub
echo "Downloading configuration files..."
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/docker-compose.yml -O docker-compose.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/prometheus-config.yml -O prometheus/prometheus.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/metrics-collector.sh -O /usr/local/bin/collect_client_metrics.sh

# Set up node_exporter service
echo "Configuring node_exporter..."
cat > /etc/init.d/node_exporter << 'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/node_exporter \
        --collector.textfile.directory="/var/lib/node_exporter/textfile_collector"
    procd_set_param respawn
    procd_close_instance
}
EOF

chmod +x /etc/init.d/node_exporter
chmod +x /usr/local/bin/collect_client_metrics.sh

# Setup cron job for metrics collection
echo "Setting up cron job..."
echo "* * * * * /usr/local/bin/collect_client_metrics.sh" > /etc/crontabs/root

# Start services
echo "Starting services..."
/etc/init.d/node_exporter enable
/etc/init.d/node_exporter start
/etc/init.d/cron restart

# Start Docker containers
echo "Starting Docker containers..."
cd /usr/local/monitoring
docker-compose up -d

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"
