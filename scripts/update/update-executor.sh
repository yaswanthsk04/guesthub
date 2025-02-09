#!/bin/bash
# Update executor script
# This script looks for and executes numbered update files

UPDATES_DIR="/usr/local/monitoring/updates"
LAST_UPDATE_FILE="/usr/local/monitoring/last_update"

# Create updates directory if it doesn't exist
mkdir -p "$UPDATES_DIR"

# Get the last executed update number
if [ -f "$LAST_UPDATE_FILE" ]; then
    last_update=$(cat "$LAST_UPDATE_FILE")
else
    last_update=0
fi

# Function to create backup with timestamp
create_backup() {
    local file="$1"
    local backup_dir="/usr/local/monitoring/backups/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp "$file" "$backup_dir/$(basename "$file").$(date +%H%M%S).bak"
    echo "Backup created in $backup_dir"
}

# Function to handle docker-compose.yml updates
handle_docker_compose() {
    local file="$1"
    echo "Updating docker-compose.yml..."
    cd /usr/local/monitoring
    
    # Create backup
    create_backup "docker-compose.yml"
    
    # Stop services
    docker-compose down
    
    # Update file
    cp "$file" docker-compose.yml
    
    # Start services
    docker-compose up -d
    echo "Docker services updated successfully"
}

# Function to handle prometheus.yml updates
handle_prometheus() {
    local file="$1"
    echo "Updating prometheus.yml..."
    cd /usr/local/monitoring
    
    # Create backup
    create_backup "prometheus/prometheus.yml"
    
    # Stop all services
    docker-compose down
    
    # Update file
    cp "$file" prometheus/prometheus.yml
    
    # Start all services
    docker-compose up -d
    echo "Prometheus configuration updated successfully"
}

# Function to handle opennds-exporter updates
handle_opennds_exporter() {
    local file="$1"
    echo "Updating opennds-exporter..."
    
    # Create backup
    create_backup "/usr/local/monitoring/opennds-exporter.py"
    
    # Stop service
    /etc/init.d/opennds-exporter stop
    
    # Update file
    cp "$file" /usr/local/monitoring/opennds-exporter.py
    chmod +x /usr/local/monitoring/opennds-exporter.py
    
    # Start service
    /etc/init.d/opennds-exporter start
    echo "OpenNDS exporter updated successfully"
}

# Function to handle update-checker.py updates
handle_update_checker() {
    local file="$1"
    echo "Updating update-checker.py..."
    
    # Create backup
    create_backup "/usr/local/monitoring/update-checker.py"
    
    # Create completion script for update-checker
    echo '#!/bin/bash
    # Wait a moment for current process
    sleep 2
    # Stop the service
    /etc/init.d/update-checker stop
    # Update the file
    cp "'$file'" "/usr/local/monitoring/update-checker.py"
    chmod +x "/usr/local/monitoring/update-checker.py"
    # Start the service
    /etc/init.d/update-checker start
    # Clean up
    rm -- "$0"
    ' > /usr/local/monitoring/update_checker_update.sh
    
    chmod +x /usr/local/monitoring/update_checker_update.sh
    
    # Launch completion script in background
    nohup /usr/local/monitoring/update_checker_update.sh >/dev/null 2>&1 &
    
    echo "Update checker staged for update"
}

# Function to handle update-executor.sh updates
handle_update_executor() {
    local file="$1"
    echo "Updating update-executor.sh..."
    local temp_executor="/usr/local/monitoring/temp_executor.sh"
    
    # Create backup
    create_backup "/usr/local/monitoring/update-executor.sh"
    
    # Copy new version to temporary location
    cp "$file" "$temp_executor"
    chmod +x "$temp_executor"
    
    # Create completion script
    echo '#!/bin/bash
    # Wait for original executor to finish
    sleep 2
    # Replace old executor with new version
    cp "'$temp_executor'" "/usr/local/monitoring/update-executor.sh"
    # Clean up
    rm "'$temp_executor'"
    rm -- "$0"
    ' > /usr/local/monitoring/finish_update.sh
    chmod +x /usr/local/monitoring/finish_update.sh
    
    # Launch completion script in background
    nohup /usr/local/monitoring/finish_update.sh >/dev/null 2>&1 &
    
    echo "Update executor staged for update"
}

# Function to log to both console and syslog
log_message() {
    echo "$1"
    logger -t "update-executor" "$1"
}

# Function to execute an update file or handle specific file updates
execute_update() {
    local update_file="$1"
    local update_num="$2"
    
    log_message "Executing update $update_num for file: $update_file"
    
    # Check if this is a specific file update
    if [[ $update_file == *"docker-compose.yml" ]]; then
        log_message "Detected docker-compose.yml update"
        handle_docker_compose "$update_file"
        if [ $? -eq 0 ]; then
            log_message "docker-compose.yml update completed successfully"
            rm -f "$update_file"  # Remove .new file after successful update
        else
            log_message "docker-compose.yml update failed"
            return 1
        fi
    elif [[ $update_file == *"prometheus.yml" ]]; then
        log_message "Detected prometheus.yml update"
        handle_prometheus "$update_file"
        if [ $? -eq 0 ]; then
            log_message "prometheus.yml update completed successfully"
            rm -f "$update_file"  # Remove .new file after successful update
        else
            log_message "prometheus.yml update failed"
            return 1
        fi
    elif [[ $update_file == *"opennds-exporter.py" ]]; then
        log_message "Detected opennds-exporter.py update"
        handle_opennds_exporter "$update_file"
        if [ $? -eq 0 ]; then
            log_message "opennds-exporter.py update completed successfully"
            rm -f "$update_file"  # Remove .new file after successful update
        else
            log_message "opennds-exporter.py update failed"
            return 1
        fi
    elif [[ $update_file == *"update-checker.py" ]]; then
        log_message "Detected update-checker.py update"
        handle_update_checker "$update_file"
        if [ $? -eq 0 ]; then
            log_message "update-checker.py update staged successfully"
            rm -f "$update_file"  # Remove .new file after successful update
        else
            log_message "update-checker.py update failed"
            return 1
        fi
    elif [[ $update_file == *"update-executor.sh" ]]; then
        log_message "Detected update-executor.sh update"
        handle_update_executor "$update_file"
        if [ $? -eq 0 ]; then
            log_message "update-executor.sh update staged successfully"
            rm -f "$update_file"  # Remove .new file after successful update
        else
            log_message "update-executor.sh update failed"
            return 1
        fi
    else
        # Regular update script
        log_message "Executing regular update script: $update_file"
        chmod +x "$update_file"
        if ! "$update_file"; then
            log_message "Update $update_num failed"
            return 1
        fi
        log_message "Regular update completed successfully"
    fi
    
    echo "$update_num" > "$LAST_UPDATE_FILE"
    echo "Update $update_num completed successfully"
    return 0
}

# Look for new updates
for update_file in "$UPDATES_DIR"/update*; do
    # Extract update number from filename
    if [[ $update_file =~ update([0-9]+) ]]; then
        update_num="${BASH_REMATCH[1]}"
        
        # Check if this update should be executed
        if [ "$update_num" -gt "$last_update" ]; then
            echo "Found new update: $update_file"
            
            # Execute the update
            if ! execute_update "$update_file" "$update_num"; then
                echo "Update $update_num failed, stopping update process"
                exit 1
            fi
        fi
    fi
done

echo "All updates completed"
exit 0
