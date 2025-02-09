#!/bin/sh

# Set correct permissions for update system components
chmod 755 /usr/local/monitoring/update-system/checker.py
chmod 755 /usr/local/monitoring/update-system/executor.sh
chmod 755 /usr/local/monitoring/update-system/executor-handler.py
chmod 755 /usr/local/monitoring/update-system/monitor.sh

# Set correct permissions for exporters
chmod 755 /usr/local/monitoring/exporters/opennds.py

# Set correct permissions for docker configs
chmod 644 /usr/local/monitoring/docker/docker-compose.yml
chmod 644 /usr/local/monitoring/docker/prometheus/config.yml

# Set correct permissions for state file
chmod 644 /usr/local/monitoring/state/last_update

# Ensure directories have correct permissions
chmod 755 /usr/local/monitoring/update-system
chmod 755 /usr/local/monitoring/docker
chmod 755 /usr/local/monitoring/docker/prometheus
chmod 755 /usr/local/monitoring/exporters
chmod 755 /usr/local/monitoring/updates
chmod 755 /usr/local/monitoring/backups
chmod 755 /usr/local/monitoring/state

# Check if update-checker service is running
if ! /etc/init.d/update-checker status | grep -q "running"; then
    logger -t "monitor-update-checker" "Update checker service not running, restarting..."
    /etc/init.d/update-checker stop
    sleep 2
    pkill -f "checker.py"  # Updated process name
    sleep 1
    /etc/init.d/update-checker start
    logger -t "monitor-update-checker" "Update checker service restarted"
else
    logger -t "monitor-update-checker" "Update checker service running normally"
fi
