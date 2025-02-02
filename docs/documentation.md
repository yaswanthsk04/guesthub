# OpenWrt Network Monitoring Setup Documentation

This documentation describes the setup and configuration of a network monitoring solution for OpenWrt using Prometheus and Grafana.

## System Overview

The monitoring system consists of the following components:

1. node_exporter: Collects system metrics from OpenWrt
2. Custom metrics collector: Gathers client connection data
3. Prometheus: Stores and queries metrics
4. Grafana: Visualizes the metrics

## Prerequisites

- OpenWrt installed and running
- Docker and Docker Compose installed
- Internet connection for downloading packages
- At least 512MB of free space

## Installation

### Automatic Installation

1. Download the setup script:
```bash
wget https://raw.githubusercontent.com/yourusername/openwrt-monitoring/main/setup.sh
chmod +x setup.sh
./setup.sh
```

### Manual Installation

1. Create necessary directories:
```bash
mkdir -p /usr/local/monitoring
mkdir -p prometheus
mkdir -p /var/lib/node_exporter/textfile_collector
```

2. Install required packages:
```bash
opkg update
opkg install curl wget conntrack node-exporter
```

3. Set up configuration files:
   - Place docker-compose.yml in /usr/local/monitoring/
   - Place prometheus.yml in /usr/local/monitoring/prometheus/
   - Place collect_client_metrics.sh in /usr/local/bin/

4. Configure node_exporter service
5. Set up cron job for metrics collection
6. Start the services

## Configuration Files

### docker-compose.yml
- Defines Prometheus and Grafana services
- Sets up networking and volumes
- Configures basic authentication for Grafana

### prometheus.yml
- Configures Prometheus scraping
- Sets up metrics collection from node_exporter
- Defines relabeling rules for network metrics

### collect_client_metrics.sh
- Collects client connection data
- Processes conntrack information
- Generates Prometheus-format metrics

## Metrics Collected

1. Client Connections
   - Active connections per client
   - Connection states (ESTABLISHED, TIME_WAIT)
   - Connection duration

2. Network Traffic
   - Bytes transferred (in/out)
   - Transfer rates

3. System Metrics
   - Network interface statistics
   - System resource usage

## Grafana Dashboard

The default dashboard includes:
1. Active Client Connections panel
2. Network Traffic Overview
3. Client Connection Details
4. System Resource Usage

## Maintenance

### Log Locations
- Prometheus: docker logs prometheus
- Grafana: docker logs grafana
- node_exporter: logread | grep node_exporter
- Metrics collector: /tmp/metrics_debug.log

### Common Tasks

1. Restart services:
```bash
docker-compose restart
/etc/init.d/node_exporter restart
```

2. Update configuration:
```bash
docker-compose down
# Update configuration files
docker-compose up -d
```

3. View metrics:
```bash
curl http://localhost:9100/metrics | grep openwrt_client
```

## Troubleshooting

1. Metrics not appearing:
   - Check node_exporter is running
   - Verify collector script permissions
   - Check Prometheus targets

2. Grafana can't connect:
   - Verify Prometheus is running
   - Check network connectivity
   - Verify correct IP addresses in configuration

3. Missing client data:
   - Check conntrack is installed
   - Verify collector script is running
   - Check textfile collector directory permissions

## Security Considerations

1. Default Credentials
   - Change Grafana admin password
   - Secure Prometheus access if exposed

2. Network Access
   - Configure firewall rules
   - Restrict access to management ports

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs
3. Contact support