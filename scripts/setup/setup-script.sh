#!/bin/sh

# OpenWrt Network Monitoring Setup Script
echo "Welcome to the installation of Gesthub v0.1.0"
uci set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
uci set system.@system[0].zonename='Europe/Berlin'
uci commit system
/etc/init.d/system restart
sleep 10  # Wait for system to stabilize

# Enable and restart WiFi
uci set wireless.radio0.disabled=0
wifi reload

echo "Installing necessary packages"
opkg update
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano python3 python3-pip opennds tailscale
pip install prometheus_client requests
echo "Starting OpenWrt monitoring services"
service dockerd enable
service dockerd start
service opennds stop
service tailscale stop


echo "Starting OpenWrt monitoring setup..."
# Create directory structure with proper permissions
echo "Creating directory structure..."
mkdir -p /usr/local/monitoring
chmod 755 /usr/local/monitoring
cd /usr/local/monitoring

# Create main directories
mkdir -p update-system docker/prometheus docker/loki docker/promtail exporters updates backups state setup-verify/logs
chmod 755 update-system docker docker/prometheus docker/loki docker/promtail exporters updates backups state setup-verify

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

# Create Grafana provisioning directories
mkdir -p docker/grafana/provisioning/datasources
mkdir -p docker/grafana/provisioning/dashboards
chmod -R 755 docker/grafana

# Function to download files from GitHub API
download_github_file() {
    local github_path=$1
    local local_path=$2
    local is_executable=${3:-false}
    
    echo "Downloading ${github_path}..."
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$local_path")"
    
    # Download file using GitHub API
    curl -H "Authorization: token ${GITHUB_TOKEN}" \
         -H "Accept: application/vnd.github.v3.raw" \
         -L \
         -o "$local_path" \
         "https://api.github.com/repos/yaswanthsk04/guesthub/contents/${github_path}?ref=v0.6.0"
    
    # Set permissions
    if [ "$is_executable" = true ]; then
        chmod 755 "$local_path"
    else
        chmod 644 "$local_path"
    fi
}

# Download configuration files
echo "Downloading configuration files..."

# Grafana provisioning
download_github_file "config/grafana/provisioning/datasources/datasource.yml" "docker/grafana/provisioning/datasources/datasource.yml"
download_github_file "config/grafana/provisioning/dashboards/dashboard.yml" "docker/grafana/provisioning/dashboards/dashboard.yml"

# Grafana dashboards
download_github_file "dashboard/update_status_dashboard.json" "docker/grafana/provisioning/dashboards/update_status_dashboard.json"
download_github_file "dashboard/system_dashboard.json" "docker/grafana/provisioning/dashboards/system_dashboard.json"
download_github_file "dashboard/network_dashboard_v3.json" "docker/grafana/provisioning/dashboards/network_dashboard_v3.json"

# Verification scripts and services
download_github_file "scripts/setup/verify-setup.sh" "/usr/local/monitoring/setup-verify/verify-setup.sh" true
download_github_file "scripts/setup/verify-setup.service" "/etc/init.d/verify-setup" true
/etc/init.d/verify-setup enable

# Docker and monitoring configs
download_github_file "config/docker-compose.yml" "docker/docker-compose.yml"
download_github_file "config/prometheus-config.yml" "docker/prometheus/prometheus-config.yml"
download_github_file "config/loki-config.yml" "docker/loki/loki-config.yml"
download_github_file "config/promtail-config.yml" "docker/promtail/promtail-config.yml"

# OpenNDS exporter
download_github_file "services/opennds-exporter.py" "exporters/opennds-exporter.py" true
download_github_file "services/opennds-exporter.service" "/etc/init.d/opennds-exporter" true
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

# Download update system components
download_github_file "scripts/update/update-checker.py" "/usr/local/monitoring/update-system/update-checker.py" true
download_github_file "scripts/update/update-checker.service" "/etc/init.d/update-checker" true
download_github_file "scripts/update/update-executor.sh" "/usr/local/monitoring/update-system/executor.sh" true


# Start update checker service
/etc/init.d/update-checker enable
/etc/init.d/update-checker start

#Configure Opennds
uci set opennds.@opennds[0].faskey="${FAS_KEY}"
uci set opennds.@opennds[0].GatewayInterface='br-lan'
uci set opennds.@opennds[0].FASEnabled='1'
uci set opennds.@opennds[0].fas_secure_enabled='1'
uci set opennds.@opennds[0].debuglevel='3'
uci set opennds.@opennds[0].fasremoteip="${FAS_REMOTE_IP}"
uci set opennds.@opennds[0].fasport='80'
uci set opennds.@opennds[0].faspath="${FAS_PATH}"
uci commit opennds
service opennds enable
service opennds start

#configure tailscale
uci set network.tailscale='interface'
uci set network.tailscale.proto='none'
uci set network.tailscale.device='tailscale0'
uci commit network

uci add firewall zone
uci set firewall.@zone[-1].name='tailscale'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].masq='1'
uci set firewall.@zone[-1].mtu_fix='1'
uci set firewall.@zone[-1].device='tailscale0'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tailscale'
uci set firewall.@forwarding[-1].dest='lan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='tailscale'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Tailscale-TCP-443'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Tailscale-UDP-41641'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].src_port='41641'
uci set firewall.@rule[-1].target='ACCEPT'


uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Tailscale-UDP-3478'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='3478'
uci set firewall.@rule[-1].target='ACCEPT'

# Commit changes and restart
uci commit firewall
service firewall restart
service tailscale start
service tailscale enable
tailscale up --auth-key="${TAILSCALE_AUTH_KEY}"

echo "Setup complete!"
echo "Access Grafana at http://your-ip:3000 (default credentials: admin/changeme)"
echo "Access Prometheus at http://your-ip:9090"
echo "Automatic updates are enabled and will check hourly"

echo "Rebooting system to apply all changes..."
sleep 5
reboot
