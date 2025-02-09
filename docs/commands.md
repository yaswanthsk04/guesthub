# GuestHub System Commands Reference

This document provides a quick reference for commonly used commands in the GuestHub system.

## Update System Commands

### Check Update Status
```bash
# View update checker logs
tail -f /var/log/update-checker.log

# Check last executed update
cat /usr/local/monitoring/last_update

# List pending updates
ls -l /usr/local/monitoring/updates/

# View update backups
ls -l /usr/local/monitoring/backups/$(date +%Y%m%d)/
```

### Update Service Management
```bash
# Restart update checker
/etc/init.d/update-checker restart

# Stop update checker
/etc/init.d/update-checker stop

# Start update checker
/etc/init.d/update-checker start

# Check update checker status
/etc/init.d/update-checker status
```

## Docker Container Commands

### Container Management
```bash
# View running containers
cd /usr/local/monitoring
docker-compose ps

# View container logs
docker-compose logs grafana
docker-compose logs prometheus

# Restart specific container
docker-compose restart grafana
docker-compose restart prometheus

# Restart all containers
docker-compose restart

# Stop all containers
docker-compose down

# Start all containers
docker-compose up -d
```

### Container Health Checks
```bash
# Check Grafana
curl -I http://localhost:3000

# Check Prometheus
curl -I http://localhost:9090

# View Prometheus targets
curl http://localhost:9090/api/v1/targets
```

## OpenNDS Commands

### Service Management
```bash
# Check OpenNDS status
/etc/init.d/opennds status

# Restart OpenNDS
/etc/init.d/opennds restart

# View OpenNDS logs
logread | grep opennds
```

### OpenNDS Exporter
```bash
# Check exporter status
/etc/init.d/opennds-exporter status

# Restart exporter
/etc/init.d/opennds-exporter restart

# View exporter logs
tail -f /var/log/opennds-exporter.log
```

## Network Commands

### Network Status
```bash
# Check network interfaces
ip addr show

# Check network connections
netstat -tulpn

# Check OpenNDS clients
ndsctl clients
```

### DHCP Status
```bash
# View DHCP leases
cat /tmp/dhcp.leases

# Check DHCP configuration
uci show dhcp

# Restart DHCP service
/etc/init.d/dnsmasq restart
```

## System Monitoring

### Resource Usage
```bash
# Check system memory
free -h

# Check disk space
df -h

# Check CPU usage
top

# Check running processes
ps aux
```

### Log Files
```bash
# System logs
logread

# Docker logs
docker-compose logs

# Update system logs
tail -f /var/log/update-checker.log

# OpenNDS logs
logread | grep opennds
```

## Backup Commands

### View Backups
```bash
# List backup directories
ls -l /usr/local/monitoring/backups/

# List today's backups
ls -l /usr/local/monitoring/backups/$(date +%Y%m%d)/

# Check backup sizes
du -sh /usr/local/monitoring/backups/*
```

### Restore from Backup
```bash
# Restore docker-compose.yml
cp /usr/local/monitoring/backups/YYYYMMDD/docker-compose.yml.HHMMSS.bak /usr/local/monitoring/docker-compose.yml

# Restore prometheus config
cp /usr/local/monitoring/backups/YYYYMMDD/prometheus.yml.HHMMSS.bak /usr/local/monitoring/prometheus/prometheus.yml

# Restore OpenNDS exporter
cp /usr/local/monitoring/backups/YYYYMMDD/opennds-exporter.py.HHMMSS.bak /usr/local/monitoring/opennds-exporter.py
```

## Troubleshooting Commands

### Service Status
```bash
# Check all services
/etc/init.d/dockerd status
/etc/init.d/opennds status
/etc/init.d/opennds-exporter status
/etc/init.d/update-checker status

# Check system service logs
logread | grep dockerd
logread | grep opennds
logread | grep update-checker
```

### Network Diagnostics
```bash
# Check network connectivity
ping 8.8.8.8

# Check DNS resolution
nslookup google.com

# Check ports in use
netstat -tulpn

# Check firewall rules
iptables -L
```

### File Permissions
```bash
# Check critical file permissions
ls -l /usr/local/monitoring/update-checker.py
ls -l /usr/local/monitoring/update-executor.sh
ls -l /usr/local/monitoring/opennds-exporter.py

# Fix permissions if needed
chmod 755 /usr/local/monitoring/update-checker.py
chmod 755 /usr/local/monitoring/update-executor.sh
chmod 755 /usr/local/monitoring/opennds-exporter.py
```

## Quick Reference

### Common Tasks
```bash
# Complete system restart
/etc/init.d/dockerd restart
/etc/init.d/opennds restart
/etc/init.d/opennds-exporter restart
/etc/init.d/update-checker restart

# View all logs
tail -f /var/log/update-checker.log & logread -f

# Check all services
for service in dockerd opennds opennds-exporter update-checker; do
    echo "=== $service ===" 
    /etc/init.d/$service status
done
```

### System Health Check
```bash
# Quick system health check
echo "=== Disk Space ===" && df -h
echo "=== Memory ===" && free -h
echo "=== Services ===" && ps aux | grep -E 'docker|opennds|update'
echo "=== Containers ===" && cd /usr/local/monitoring && docker-compose ps
echo "=== Updates ===" && tail -n 20 /var/log/update-checker.log
