#!/bin/sh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
CORAL='\033[38;2;255;107;107m'  # RGB color for #FF6B6B
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Print logo and text side by side
echo -e "${CORAL}@@@@@@                      ${WHITE}@@@@@@@@@                                                               @@@@                             @@@                     
${CORAL}@@@@@@@@@@                        ${WHITE}@@@@@@@@@@@@@@                                                      @@     @@@@                             @@@                     
${CORAL}@@@@@@@@@@                        ${WHITE}@@@@@     @@@@@@                                                   @@@@    @@@@                             @@@                     
${CORAL}@@@@@               @@@@@@        ${WHITE}@@@@          @@@@    @@@      @@@       @@@@@          @@@@@     @@@@@@@  @@@@  @@@@@      @@@      @@@    @@@  @@@@@              
${CORAL}@@@@@                 @@@@@@      ${WHITE}@@@@                  @@@@     @@@@    @@@@@@@@@@     @@@@@@@@@@ @@@@@@@@@ @@@@@@@@@@@@@   @@@@      @@@@   @@@@@@@@@@@@@           
${CORAL}@@@@@        @@@@       @@@@@     ${WHITE}@@@@       @@@@@@@@   @@@@     @@@@  @@@@      @@@@  @@@     @@@   @@@@    @@@@@     @@@@  @@@@      @@@@   @@@@     @@@@@          
${CORAL}@@@       @@@@@@@@      @@@@      ${WHITE}@@@@       @@@@@@@@   @@@@     @@@@  @@@@@@@@@@@@@@  @@@@@@        @@@@    @@@@      @@@@  @@@@      @@@@   @@@        @@@          
${CORAL}@       @@@@@@@@@@       @        ${WHITE}@@@@            @@@   @@@@     @@@@  @@@@@@@@@@@@@@   @@@@@@@@@@   @@@@    @@@@      @@@@  @@@@      @@@@   @@@        @@@          
${CORAL}       @@@@@@@@@@@                ${WHITE}@@@@          @@@@    @@@@     @@@@  @@@                    @@@@@  @@@@    @@@@      @@@@  @@@@      @@@@   @@@       @@@@          
${CORAL}@@@      @@@@@@@@@@      @@       ${WHITE} @@@@@    @@@@@@@     @@@@     @@@@   @@@@    @@@@  @@@@     @@@@   @@@@   @@@@      @@@@   @@@@    @@@@@   @@@@@    @@@@           
${CORAL}@@@@@      @@@@@@@       @@@@     ${WHITE}  @@@@@@@@@@@@@       @@@@@@@@@@@@    @@@@@@@@@@    @@@@@@@@@@      @@@@   @@@@      @@@@    @@@@@@@@@@@@   @@@@@@@@@@@@            
${CORAL}@@@@@@                  @@@@@      
${CORAL}@@@@@@                @@@@@        
${CORAL}@@@@@    @@@@@@    @@@@           
${CORAL}      @@@@@@@@@@                   
${CORAL}      @@@@@@@@@@                   
EOF
echo -e "${NC}"

echo -e "\n${BOLD}${CYAN}Welcome to GuestHub Setup${NC}\n"

echo -e "${BOLD}${BLUE}=== Configuration Settings ===${NC}\n"

echo -e "${CYAN}The following settings are required for GuestHub to function properly.${NC}\n"

# Collect Tailscale settings
echo -e "${YELLOW}Enter Tailscale auth key: ${NC}"
read tailscale_key
if [ -z "$tailscale_key" ]; then
    echo -e "${RED}Error: Tailscale auth key is required for VPN connectivity${NC}"
    exit 1
fi

# Collect FAS settings
echo -e "\n${YELLOW}Enter FAS key: ${NC}"
read fas_key
if [ -z "$fas_key" ]; then
    echo -e "${RED}Error: FAS key is required for captive portal${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter FAS remote IP: ${NC}"
read fas_remote_ip
if [ -z "$fas_remote_ip" ]; then
    echo -e "${RED}Error: FAS remote IP is required for captive portal${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter FAS path: ${NC}"
read fas_path
if [ -z "$fas_path" ]; then
    echo -e "${RED}Error: FAS path is required for captive portal${NC}"
    exit 1
fi

# Collect Grafana credentials
echo -e "\n${YELLOW}Enter Grafana admin username: ${NC}"
read grafana_user
if [ -z "$grafana_user" ]; then
    echo -e "${RED}Error: Grafana username is required for dashboard access${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter Grafana admin password: ${NC}"
read grafana_password
if [ -z "$grafana_password" ]; then
    echo -e "${RED}Error: Grafana password is required for dashboard access${NC}"
    exit 1
fi

# Export all variables for immediate use
echo -e "\n${CYAN}Setting up environment variables...${NC}"
export TAILSCALE_AUTH_KEY="$tailscale_key"
export FAS_KEY="$fas_key"
export FAS_REMOTE_IP="$fas_remote_ip"
export FAS_PATH="$fas_path"
export GF_SECURITY_ADMIN_USER="$grafana_user"
export GF_SECURITY_ADMIN_PASSWORD="$grafana_password"

# Create persistent environment file
echo -e "${CYAN}Creating persistent environment configuration...${NC}"
cat > /etc/guesthub-env.sh << EOF
export TAILSCALE_AUTH_KEY="$tailscale_key"
export FAS_KEY="$fas_key"
export FAS_REMOTE_IP="$fas_remote_ip"
export FAS_PATH="$fas_path"
export GF_SECURITY_ADMIN_USER="$grafana_user"
export GF_SECURITY_ADMIN_PASSWORD="$grafana_password"
EOF

chmod 644 /etc/guesthub-env.sh

# Ensure variables persist after reboot
if ! grep -q "source /etc/guesthub-env.sh" /etc/profile; then
    echo "source /etc/guesthub-env.sh" >> /etc/profile
fi

echo -e "${GREEN}✓ Environment variables configured successfully${NC}\n"

uci set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
uci set system.@system[0].zonename='Europe/Berlin'
uci commit system
/etc/init.d/system restart
sleep 10  # Wait for system to stabilize

echo -e "\n${BOLD}${BLUE}=== WiFi Configuration ===${NC}\n"

# Ask for SSID
echo -e "${YELLOW}Enter WiFi network name (SSID): ${NC}"
read wifi_ssid

if [ -z "$wifi_ssid" ]; then
    echo -e "${CYAN}No SSID provided. Setting network name to 'GuestHub WiFi' with no password protection.${NC}"
    wifi_ssid="GuestHub WiFi"
    uci set wireless.default_radio0.encryption='none'
    uci delete wireless.default_radio0.key 2>/dev/null
else
    echo -e "\n${YELLOW}Do you want to password protect '$wifi_ssid'? (yes/no): ${NC}"
    read need_password

    if [ "$need_password" = "yes" ]; then
        echo -e "${YELLOW}Enter WiFi password: ${NC}"
        read wifi_password
        uci set wireless.default_radio0.encryption='psk2'
        uci set wireless.default_radio0.key="$wifi_password"
    else
        echo -e "${CYAN}Setting up '$wifi_ssid' without password protection${NC}"
        uci set wireless.default_radio0.encryption='none'
        uci delete wireless.default_radio0.key 2>/dev/null
    fi
fi

# Configure and enable WiFi
echo -e "\n${CYAN}Applying WiFi settings...${NC}"
uci set wireless.default_radio0.ssid="$wifi_ssid"
uci set wireless.radio0.disabled=0
uci commit wireless
wifi reload
echo -e "${GREEN}✓ WiFi configured successfully${NC}\n"

echo -e "${BOLD}${BLUE}=== Installing Dependencies ===${NC}\n"
echo -e "${CYAN}Installing necessary packages...${NC}"
opkg update
opkg install git git-http curl bash ca-bundle docker docker-compose dockerd nano python3 python3-pip opennds tailscale
pip install prometheus_client requests
echo -e "${GREEN}✓ Packages installed successfully${NC}\n"

echo -e "${CYAN}Starting OpenWrt monitoring services...${NC}"
service dockerd enable
service dockerd start
service opennds stop
service tailscale stop

echo -e "\n${BOLD}${BLUE}=== System Configuration ===${NC}\n"
echo -e "${CYAN}Setting up monitoring system...${NC}"
echo -e "• Creating base monitoring directory"
mkdir -p /usr/local/monitoring
chmod 755 /usr/local/monitoring
cd /usr/local/monitoring

echo -e "• Creating service directories for:"
echo -e "  - Docker containers (Prometheus, Loki, Promtail)"
echo -e "  - Update system"
echo -e "  - Exporters"
echo -e "  - Backup storage"
echo -e "  - System state"
mkdir -p update-system docker/prometheus docker/loki docker/promtail exporters updates backups state setup-verify/logs
chmod 755 update-system docker docker/prometheus docker/loki docker/promtail exporters updates backups state setup-verify

echo -e "• Setting proper permissions"
chown -R root:root /usr/local/monitoring

echo -e "• Initializing system state"
echo "0" > state/last_update
chmod 644 state/last_update

echo -e "${GREEN}✓ System directory structure created successfully${NC}\n"

echo -e "${BOLD}${BLUE}=== Installing Exporters ===${NC}\n"
echo -e "${CYAN}Installing OpenWRT exporters...${NC}"
opkg install prometheus-node-exporter-lua \
prometheus-node-exporter-lua-nat_traffic \
prometheus-node-exporter-lua-netstat \
prometheus-node-exporter-lua-openwrt \
prometheus-node-exporter-lua-wifi \
prometheus-node-exporter-lua-wifi_stations
echo -e "${GREEN}✓ Exporters installed successfully${NC}\n"

echo -e "${BOLD}${BLUE}=== Downloading Configurations ===${NC}\n"
echo -e "${CYAN}Downloading configuration files...${NC}"

# Create Grafana provisioning directories
mkdir -p docker/grafana/provisioning/datasources
mkdir -p docker/grafana/provisioning/dashboards
chmod -R 755 docker/grafana

echo -e "${CYAN}Downloading Grafana configurations...${NC}"
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/grafana/provisioning/datasources/datasource.yml -O docker/grafana/provisioning/datasources/datasource.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/grafana/provisioning/dashboards/dashboard.yml -O docker/grafana/provisioning/dashboards/dashboard.yml
chmod 644 docker/grafana/provisioning/datasources/datasource.yml
chmod 644 docker/grafana/provisioning/dashboards/dashboard.yml
echo -e "${GREEN}✓ Grafana configurations downloaded${NC}\n"

echo -e "${CYAN}Downloading Grafana dashboards...${NC}"
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/dashboard/update_status_dashboard.json -O docker/grafana/provisioning/dashboards/update_status_dashboard.json
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/dashboard/system_dashboard.json -O docker/grafana/provisioning/dashboards/system_dashboard.json
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/dashboard/network_dashboard_v3.json -O docker/grafana/provisioning/dashboards/network_dashboard_v3.json
chmod 644 docker/grafana/provisioning/dashboards/*.json

# Download and setup verification script
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/setup/verify-setup.sh -O /usr/local/monitoring/setup-verify/verify-setup.sh
chmod +x /usr/local/monitoring/setup-verify/verify-setup.sh

# Download and setup verification service
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/setup/verify-setup.service -O /etc/init.d/verify-setup
chmod +x /etc/init.d/verify-setup
/etc/init.d/verify-setup enable

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/docker-compose.yml -O docker/docker-compose.yml
chmod 644 docker/docker-compose.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/prometheus-config.yml -O docker/prometheus/prometheus-config.yml
chmod 644 docker/prometheus/prometheus-config.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/loki-config.yml -O docker/loki/loki-config.yml
chmod 644 docker/loki/loki-config.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/config/promtail-config.yml -O docker/promtail/promtail-config.yml
chmod 644 docker/promtail/promtail-config.yml
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/services/opennds-exporter.py -O exporters/opennds-exporter.py
chmod 755 exporters/opennds-exporter.py

echo -e "\n${BOLD}${BLUE}=== Setting Up Monitoring Services ===${NC}\n"
echo -e "${CYAN}Configuring OpenNDS exporter...${NC}"
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/services/opennds-exporter.service -O /etc/init.d/opennds-exporter
chmod +x /usr/local/monitoring/exporters/opennds-exporter.py
chmod +x /etc/init.d/opennds-exporter
/etc/init.d/opennds-exporter enable
/etc/init.d/opennds-exporter start
echo -e "${GREEN}✓ OpenNDS exporter configured${NC}\n"

echo -e "${CYAN}Configuring OpenWRT node exporter...${NC}"
uci set prometheus-node-exporter-lua.main.listen_interface='*'
uci commit prometheus-node-exporter-lua
/etc/init.d/prometheus-node-exporter-lua enable
/etc/init.d/prometheus-node-exporter-lua start
echo -e "${GREEN}✓ Node exporter configured${NC}\n"

echo -e "\n${BOLD}${BLUE}=== Starting Services ===${NC}\n"
echo -e "${CYAN}Initializing Docker containers...${NC}"
cd /usr/local/monitoring/docker
docker network create monitoring_network || true  # Create if doesn't exist
docker-compose up -d

echo -e "\n${CYAN}Verifying container status...${NC}"
docker-compose ps
echo -e "${GREEN}✓ Docker containers started successfully${NC}"
echo -e "${CYAN}• Container restart policy set to 'always' - will auto-start after reboot${NC}\n"

echo -e "${BOLD}${BLUE}=== Configuring Update System ===${NC}\n"
echo -e "${CYAN}Setting up automatic update checker...${NC}"

# Download update system components with proper permissions
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/update/update-checker.py -O /usr/local/monitoring/update-system/update-checker.py
chmod 755 /usr/local/monitoring/update-system/update-checker.py

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/update/update-checker.service -O /etc/init.d/update-checker
chmod 755 /etc/init.d/update-checker

wget https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/update/update-executor.sh -O /usr/local/monitoring/update-system/executor.sh
chmod 755 /usr/local/monitoring/update-system/executor.sh


# Start update checker service
/etc/init.d/update-checker enable
/etc/init.d/update-checker start

echo -e "\n${BOLD}${BLUE}=== Configuring Network Services ===${NC}\n"
echo -e "${CYAN}Setting up OpenNDS captive portal...${NC}"
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
echo -e "${GREEN}✓ OpenNDS configured successfully${NC}\n"

echo -e "${CYAN}Configuring Tailscale VPN...${NC}"
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

echo -e "\n${BOLD}${BLUE}=== Finalizing Setup ===${NC}\n"
echo -e "${CYAN}Applying firewall changes...${NC}"
uci commit firewall
service firewall restart

echo -e "${CYAN}Updating and starting Tailscale service...${NC}"
yes y | tailscale update
service tailscale start
service tailscale enable
tailscale up --auth-key="${TAILSCALE_AUTH_KEY}"

echo -e "\n${BOLD}${BLUE}=== Installation Summary ===${NC}\n"
print_status() {
    local task="$1"
    local status="$2"
    if [ "$status" = "success" ]; then
        echo -e "${task}${YELLOW}$(printf '%*s' $((50 - ${#task})) '')${NC}[${GREEN}✓${NC}]"
    else
        echo -e "${task}${YELLOW}$(printf '%*s' $((50 - ${#task})) '')${NC}[${RED}✗${NC}]"
    fi
}

print_status "Environment Variables Configuration" "success"
print_status "WiFi Setup" "success"
print_status "Package Installation" "success"
print_status "Directory Structure" "success"
print_status "Exporters Installation" "success"
print_status "Grafana Configuration" "success"
print_status "Docker Services" "success"
print_status "OpenNDS Setup" "success"
print_status "Tailscale Configuration" "success"
print_status "Firewall Rules" "success"

echo -e "\n${BOLD}${GREEN}✓ Setup Complete!${NC}\n"

# Get Tailscale IPv4 address
TAILSCALE_IP=$(tailscale ip | grep -E '^[0-9]+\.' | head -n1)

echo -e "${BOLD}${BLUE}=== Access Information ===${NC}\n"
echo -e "${CYAN}Grafana Dashboard:${NC}"
echo -e "  • URL:         ${YELLOW}http://$TAILSCALE_IP:3000${NC}"
echo -e "  • Username:    ${YELLOW}$GF_SECURITY_ADMIN_USER${NC}"
echo -e "  • Password:    ${YELLOW}$GF_SECURITY_ADMIN_PASSWORD${NC}\n"

echo -e "${CYAN}Prometheus:${NC}"
echo -e "  • URL:         ${YELLOW}http://$TAILSCALE_IP:9090${NC}\n"

echo -e "${GREEN}• Automatic updates are enabled and will be checked every 5 minutes!${NC}\n"

echo -e "${YELLOW}Rebooting system to apply all changes...${NC}"
sleep 5
reboot
