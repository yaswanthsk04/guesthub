# GuestHub Setup Guide

## Quick Setup

1. Download and run the setup script:
```bash
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/setup/setup-script.sh
chmod +x setup-script.sh
./setup-script.sh
```

## Essential Commands

### Service Management
```bash
# Start/Stop/Restart Update Checker
/etc/init.d/update-checker start
/etc/init.d/update-checker stop
/etc/init.d/update-checker restart

# Start/Stop/Restart Docker Services
cd /usr/local/monitoring/docker
docker-compose up -d    # Start
docker-compose down     # Stop
docker-compose restart  # Restart

# Check Service Status
/etc/init.d/update-checker status
docker-compose ps
```

### Monitoring
```bash
# View Update Logs
tail -f /var/log/update-checker.log

# View Docker Logs
cd /usr/local/monitoring/docker
docker-compose logs -f

# Check System Status
docker-compose ps
```

### Access Services
- Grafana: http://your-ip:3000 (default credentials: admin/changeme)
- Prometheus: http://your-ip:9090

## Documentation
- [System Documentation](documentation.md) - How the system works
- [Update System](updates.md) - How updates work

## Directory Structure
```
/usr/local/monitoring/
├── docker/
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   └── prometheus-config.yml
│   ├── loki/
│   │   └── loki-config.yml
│   └── promtail/
│       └── promtail-config.yml
├── update-system/
│   ├── checker.py
│   └── executor.sh
└── exporters/
    └── opennds-exporter.py
