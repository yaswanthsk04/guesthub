# GuestHub v0.1.0

OpenWrt Network Monitoring System with automatic updates.

## Repository Structure

```
/
├── scripts/         # Core system scripts
│   ├── setup/      # Installation scripts
│   │   └── setup-script.sh
│   └── update/     # Update system
│       ├── update-checker.py
│       ├── update-checker.service
│       └── update-executor.sh
├── services/        # Service implementations
│   ├── opennds-exporter.py
│   └── opennds-exporter.service
├── config/          # Configuration files
│   ├── docker-compose.yml
│   └── prometheus-config.yml
├── dashboard/       # Grafana dashboards
│   ├── network_dashboard.json
│   └── system_dashboard.json
├── updates/         # System update files
│   ├── update1     # First update
│   └── update2     # Second update
└── docs/           # Documentation
    └── documentation.md

## Features

1. **Simple Update System**
   - Create numbered update files (update1, update2, etc.)
   - Updates run in sequence automatically
   - Each update is a self-contained bash script
   - System tracks executed updates

2. **Monitoring**
   - OpenNDS metrics collection
   - Prometheus metrics storage
   - Grafana dashboards for visualization

## Installation

Run the setup script:
```bash
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main/scripts/setup/setup-script.sh
chmod +x setup-script.sh
./setup-script.sh
```

## Making Updates

The system supports two types of updates:

1. Core File Updates:
   The system automatically handles updates to all core files:

   Case 1: docker-compose.yml updates
   - System detects changes in GitHub
   - Creates backup of current file in /usr/local/monitoring/backups/YYYYMMDD/
   - Runs docker-compose down
   - Updates the file
   - Runs docker-compose up -d

   Case 2: prometheus-config.yml updates
   - System detects changes in GitHub
   - Creates backup of current file in /usr/local/monitoring/backups/YYYYMMDD/
   - Runs docker-compose down to stop all services
   - Updates the configuration
   - Runs docker-compose up -d to start all services

   Case 3: opennds-exporter.py updates
   - System detects changes in GitHub
   - Creates backup of current file
   - Stops opennds-exporter service
   - Updates the file
   - Makes it executable
   - Starts opennds-exporter service

   Case 4: update-checker.py updates
   - System detects changes in GitHub
   - Creates backup of current file
   - Stops update-checker service
   - Updates the file
   - Makes it executable
   - Starts update-checker service

   Case 5: update-executor.sh updates
   - System detects changes in GitHub
   - Creates backup of current file
   - Stages new version in temporary location
   - Completes current operations
   - Automatically switches to new version

2. Command Script Updates:
   For custom commands and system changes:
   - Create numbered update files in GitHub's updates/ directory
   - Name format: update1, update2, update3, ..., update116, etc.
   - System automatically:
     * Discovers all update files in GitHub
     * Sorts them by number
     * Downloads and executes in sequence
     * Tracks last executed update
   - Examples:
     ```bash
     # updates/update1
     #!/bin/bash
     # First update
     cd /usr/local/monitoring
     docker-compose exec grafana grafana-cli plugins install grafana-clock-panel
     
     # updates/update27
     #!/bin/bash
     # Later update
     sed -i 's/old_value/new_value/' /etc/some-config.conf
     systemctl restart some-service
     
     # updates/update116
     #!/bin/bash
     # Much later update
     docker system prune -f
     docker-compose pull
     docker-compose up -d
     ```
   
   The system keeps track of the last executed update number, so:
   - New updates are detected automatically
   - Only updates newer than the last executed update are run
   - Updates always run in numerical order
   - No limit to the number of updates

The update system will:
1. Check GitHub every 5 minutes for changes
   - Checks 3 core files (36 requests/hour)
   - Stays within GitHub's rate limit (60 requests/hour)
2. When changes detected:
   - Creates timestamped backups
   - Safely stops affected services
   - Updates files
   - Restarts services
3. Logs all activities to /var/log/update-checker.log

Note: The 5-minute check interval is optimized for:
- Quick response to changes
- GitHub API rate limits (60 requests/hour for unauthenticated access)
- Minimal system resource usage
