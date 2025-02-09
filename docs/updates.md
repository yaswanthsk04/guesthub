# GuestHub Update System Documentation

## Overview
The GuestHub update system provides automatic updates for both system files and custom update scripts. It handles updates in a specific order to ensure system stability and proper service management.

## Components

### 1. Update Checker (update-checker.py)
- Runs as a system service
- Checks GitHub repository every 5 minutes
- Monitors core system files and update scripts
- Uses GitHub API within rate limits (60 requests/hour)

### 2. Update Executor (update-executor.sh)
- Handles file updates and service management
- Provides specialized handlers for different file types
- Manages service restarts and container updates
- Creates backups before updates

## Update Types

### 1. Core File Updates
Files are updated in this specific order:
1. docker-compose.yml
   - Stops all containers
   - Updates configuration
   - Restarts containers

2. prometheus-config.yml
   - Stops Prometheus container
   - Updates configuration
   - Restarts Prometheus

3. opennds-exporter.py
   - Stops OpenNDS exporter service
   - Updates exporter
   - Restarts service

4. update-executor.sh
   - Creates backup
   - Stages new version in temporary location
   - Completes current operations
   - Switches to new version automatically

5. update-checker.py
   - Creates backup
   - Stages update
   - Stops service
   - Updates file
   - Restarts with new version

### 2. Custom Update Scripts
- Located in updates/ directory
- Named numerically (update1, update2, etc.)
- Executed in numerical order
- Each script runs only once
- Progress tracked in last_update file

## Update Process

### File Updates
1. Update checker detects changes:
   ```python
   def check_core_files():
       for github_path in UPDATE_ORDER:
           # Check if file changed
           if changed:
               # Create temporary file
               # Call update executor
   ```

2. Update executor handles the update:
   ```bash
   # For each file type:
   handle_specific_file() {
       # Create backup
       # Stop related services
       # Update file
       # Start services
   }
   ```

### Update Scripts
1. Checker looks for new scripts:
   ```python
   def check_update_scripts():
       remote_updates = get_remote_updates()
       for update in remote_updates:
           if not exists_locally:
               download_and_execute()
   ```

2. Scripts are executed in order:
   ```bash
   # Example update script
   #!/bin/bash
   # Update network configuration
   uci set network.lan.ipaddr='192.168.2.1'
   uci commit network
   service network restart
   ```

## Backup System
- All updates create backups before changes
- Backups stored in: /usr/local/monitoring/backups/YYYYMMDD/
- Named with timestamps: filename.HHMMSS.bak
- Allows for recovery if needed

## Logging
All update activities are logged to /var/log/update-checker.log:
- Update detections
- File changes
- Service operations
- Errors and failures

## Example Update Scenarios

### 1. Multiple File Updates
If multiple files are updated in one commit:
```
Changes:
- docker-compose.yml
- update-checker.py
- update-executor.sh

Process:
1. docker-compose.yml updated first
2. update-executor.sh stages its update
3. update-checker.py updates last
```

### 2. Custom Update Script
```bash
# updates/update1
#!/bin/bash
# Update network settings
uci set network.lan.netmask='255.255.254.0'
uci commit network
service network restart
```

### 3. Service Configuration Update
```yaml
# Updated docker-compose.yml
services:
  grafana:
    ports:
      - "3001:3000"  # Port change
```

## Troubleshooting

### Common Issues
1. Update Not Applying
   - Check /var/log/update-checker.log
   - Verify file permissions
   - Check service status

2. Failed Updates
   - Check backup directory for previous version
   - Review error logs
   - Verify service status

### Recovery
1. From Failed Update:
   ```bash
   # Restore from backup
   cp /usr/local/monitoring/backups/YYYYMMDD/file.HHMMSS.bak original_location
   ```

2. Restart Services:
   ```bash
   # Restart update system
   /etc/init.d/update-checker restart
   ```

## Best Practices

1. Update Files
   - Test changes locally first
   - Include clear comments
   - Follow update order
   - Backup critical data

2. Update Scripts
   - Use sequential numbering
   - Include error handling
   - Add logging statements
   - Test thoroughly

3. Service Updates
   - Plan for downtime
   - Backup configurations
   - Test rollback procedures
