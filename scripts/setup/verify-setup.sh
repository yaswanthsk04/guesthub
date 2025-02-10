#!/bin/sh

# Set up logging
LOG_DIR="/usr/local/monitoring/setup-verify/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/verify-setup_$(date '+%Y%m%d_%H%M%S').log"
{
echo "\n=== System Verification Run - $(date '+%Y-%m-%d %H:%M:%S') ===" 
echo "Performing post-reboot verification checks..."
sleep 30  # Wait for all services to fully start

# Check Network Configuration
echo "\nVerifying Network Configuration:"
ifconfig lan | grep "inet addr"
echo "Network Mask:" 
uci get network.lan.netmask

# Check DHCP Configuration
echo "\nVerifying DHCP Configuration:"
uci show dhcp.lan
echo "Static DHCP Entry:"
uci show dhcp.@host[-1]
ps | grep dnsmasq

# Check WiFi Status
echo "\nVerifying WiFi Status:"
wifi status
iwinfo

# Check Docker Status
echo "\nVerifying Docker Services:"
docker ps
docker-compose -f /usr/local/monitoring/docker/docker-compose.yml ps

# Check OpenNDS Status
echo "\nVerifying OpenNDS Service:"
/etc/init.d/opennds status
ps | grep opennds

# Check Monitoring Services
echo "\nVerifying Monitoring Services:"
/etc/init.d/prometheus-node-exporter-lua status
/etc/init.d/opennds-exporter status
/etc/init.d/update-checker status

echo "\nVerification complete. Please review the output above for any errors."
echo "=== Verification Completed at $(date) ==="
echo "Log file available at: $LOG_FILE"
echo "=== End of Verification Run at $(date '+%Y-%m-%d %H:%M:%S') ===\n"
} 2>&1 | tee "$LOG_FILE"
