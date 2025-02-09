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

# Function to log to both console and syslog with timestamp and level
log_message() {
    local timestamp level="INFO" message="$1"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # If first argument is INFO or ERROR, use it as level
    if [ "$1" = "INFO" ] || [ "$1" = "ERROR" ]; then
        level="$1"
        message="$2"
    fi
    
    echo "[$timestamp] update-executor: $level - $message"
    logger -t "update-executor" "[$timestamp] $level - $message"
}

# Function to log error messages
log_error() {
    log_message "ERROR" "$1"
}

# Function to create backup with timestamp
create_backup() {
    local file="$1"
    local backup_dir="/usr/local/monitoring/backups/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp "$file" "$backup_dir/$(basename "$file").$(date +%H%M%S).bak"
    log_message "INFO" "Backup created in $backup_dir"
}

# Function to handle docker-compose.yml updates
handle_docker_compose() {
    local file="$1"
    log_message "INFO" "Updating docker-compose.yml..."
    cd /usr/local/monitoring || return 1
    
    # Create backup
    create_backup "docker-compose.yml"
    
    # Stop services
    log_message "INFO" "Stopping Docker services..."
    docker-compose down
    
    # Update file
    log_message "INFO" "Updating docker-compose.yml file..."
    cp "$file" docker-compose.yml
    
    # Start services
    log_message "INFO" "Starting Docker services..."
    docker-compose up -d
    
    # Verify services are running
    if docker-compose ps | grep -q "Up"; then
        log_message "INFO" "Docker services updated and running successfully"
        return 0
    else
        log_error "Docker services failed to start"
        return 1
    fi
}

# Function to handle prometheus.yml updates
handle_prometheus() {
    local file="$1"
    log_message "INFO" "Updating prometheus.yml..."
    cd /usr/local/monitoring || return 1
    
    # Ensure prometheus directory exists
    mkdir -p prometheus
    chmod 755 prometheus
    
    # Create backup
    create_backup "prometheus/prometheus.yml"
    
    # Stop all services
    log_message "INFO" "Stopping Docker services..."
    docker-compose down
    
    # Update file
    log_message "INFO" "Updating prometheus.yml file..."
    cp "$file" prometheus/prometheus.yml
    chmod 644 prometheus/prometheus.yml
    log_message "INFO" "Copied new prometheus config to: prometheus/prometheus.yml"
    
    # Start all services
    log_message "INFO" "Starting Docker services..."
    docker-compose up -d
    
    # Verify services are running
    if docker-compose ps | grep -q "Up"; then
        log_message "INFO" "Prometheus configuration updated and services running successfully"
        return 0
    else
        log_error "Services failed to start after prometheus update"
        return 1
    fi
}

# Function to handle opennds-exporter updates
handle_opennds_exporter() {
    local file="$1"
    log_message "INFO" "Updating opennds-exporter..."
    
    # Create backup
    create_backup "/usr/local/monitoring/opennds-exporter.py"
    
    # Stop service
    log_message "INFO" "Stopping OpenNDS exporter..."
    /etc/init.d/opennds-exporter stop
    
    # Update file
    log_message "INFO" "Updating opennds-exporter.py file..."
    cp "$file" /usr/local/monitoring/opennds-exporter.py
    chmod +x /usr/local/monitoring/opennds-exporter.py
    
    # Start service
    log_message "INFO" "Starting OpenNDS exporter..."
    /etc/init.d/opennds-exporter start
    
    # Verify service is running
    if /etc/init.d/opennds-exporter status | grep -q "running"; then
        log_message "INFO" "OpenNDS exporter updated and running successfully"
        return 0
    else
        log_error "OpenNDS exporter failed to start"
        return 1
    fi
}

# Function to handle update-checker.py updates
handle_update_checker() {
    local file="$1"
    log_message "INFO" "Updating update-checker.py..."
    
    # Create backup
    create_backup "/usr/local/monitoring/update-checker.py"
    
    # Stop service and kill any remaining processes
    log_message "INFO" "Stopping update checker service..."
    /etc/init.d/update-checker stop
    sleep 2
    pkill -f "update-checker.py"
    
    # Update file
    log_message "INFO" "Installing new update checker..."
    cp "$file" /usr/local/monitoring/update-checker.py
    chmod +x /usr/local/monitoring/update-checker.py
    rm -f "$file"  # Remove the .new file immediately
    
    # Start service
    log_message "INFO" "Starting update checker service..."
    /etc/init.d/update-checker start
    
    log_message "INFO" "Update checker updated successfully"
    return 0
}

# Function to handle update-executor.sh updates
handle_update_executor() {
    local file="$1"
    log_message "INFO" "Updating update-executor.sh..."
    local temp_executor="/usr/local/monitoring/temp_executor.sh"
    
    # Create backup
    create_backup "/usr/local/monitoring/update-executor.sh"
    
    # Copy new version to temporary location
    cp "$file" "$temp_executor"
    chmod +x "$temp_executor"
    rm -f "$file"  # Remove the .new file immediately
    
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
    
    log_message "INFO" "Update executor staged for update"
    return 0
}

# Function to handle batch docker updates
handle_docker_batch() {
    local file="$1"
    local is_batch="$2"
    
    if [[ $file == *"docker-compose.yml"* ]]; then
        log_message "INFO" "Handling docker-compose.yml in batch mode..."
        cd /usr/local/monitoring || return 1
        
        # Create backup
        create_backup "docker-compose.yml"
        
        if [ "$is_batch" != "--batch" ]; then
            # If not in batch mode, stop services
            log_message "INFO" "Stopping Docker services..."
            docker-compose down
        fi
        
        # Update file
        log_message "INFO" "Updating docker-compose.yml file..."
        cp "$file" docker-compose.yml
        rm -f "$file"  # Remove the .new file immediately
        
        if [ "$is_batch" != "--batch" ]; then
            # If not in batch mode, start services
            log_message "INFO" "Starting Docker services..."
            docker-compose up -d
            
            # Verify services
            if docker-compose ps | grep -q "Up"; then
                log_message "INFO" "Docker services updated and running successfully"
                return 0
            else
                log_error "Docker services failed to start"
                return 1
            fi
        fi
        return 0
    elif [[ $file == *"prometheus.yml"* ]]; then
        log_message "INFO" "Handling prometheus.yml in batch mode..."
        cd /usr/local/monitoring || return 1
        
        # Ensure prometheus directory exists
        mkdir -p prometheus
        chmod 755 prometheus
        
        # Create backup
        create_backup "prometheus/prometheus.yml"
        
        if [ "$is_batch" != "--batch" ]; then
            # If not in batch mode, stop services
            log_message "INFO" "Stopping Docker services..."
            docker-compose down
        fi
        
        # Update file
        log_message "INFO" "Updating prometheus.yml file..."
        cp "$file" prometheus/prometheus.yml
        chmod 644 prometheus/prometheus.yml
        rm -f "$file"  # Remove the .new file immediately
        
        if [ "$is_batch" != "--batch" ]; then
            # If not in batch mode, start services
            log_message "INFO" "Starting Docker services..."
            docker-compose up -d
            
            # Verify services
            if docker-compose ps | grep -q "Up"; then
                log_message "INFO" "Prometheus configuration updated and services running successfully"
                return 0
            else
                log_error "Services failed to start after prometheus update"
                return 1
            fi
        fi
        return 0
    fi
}

# Function to execute an update file or handle specific file updates
execute_update() {
    local update_file="$1"
    local update_num="$2"
    local is_batch="$3"
    
    log_message "INFO" "Processing update file: $update_file"
    
    # Check if this is a specific file update
    if [[ $update_file == *".new" ]]; then
        # Extract base name without .new
        local base_name
        base_name=$(basename "$update_file" .new)
        
        case "$base_name" in
            "docker-compose.yml"|"prometheus.yml"|"prometheus/prometheus.yml")
                if [ "$is_batch" == "--batch" ]; then
                    handle_docker_batch "$update_file" "$is_batch"
                    # If this is the last batch update, start services
                    if [[ $update_file == *"prometheus.yml"* ]]; then
                        log_message "INFO" "Batch updates complete, starting services..."
                        cd /usr/local/monitoring || return 1
                        docker-compose up -d
                        if docker-compose ps | grep -q "Up"; then
                            log_message "INFO" "Services started successfully after batch update"
                        else
                            log_error "Services failed to start after batch update"
                            return 1
                        fi
                    fi
                else
                    if [[ $base_name == "docker-compose.yml" ]]; then
                        handle_docker_compose "$update_file"
                    else
                        handle_prometheus "$update_file"
                    fi
                fi
                ;;
            "opennds-exporter.py")
                handle_opennds_exporter "$update_file"
                ;;
            "update-checker.py")
                handle_update_checker "$update_file"
                ;;
            "update-executor.sh")
                handle_update_executor "$update_file"
                ;;
            *)
                log_error "Unknown file type: $base_name"
                return 1
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            log_message "INFO" "Update completed successfully for $base_name"
            return 0
        else
            log_error "Update failed for $base_name"
            return 1
        fi
    else
        # Regular update script
        log_message "INFO" "Executing update script: $update_file"
        chmod +x "$update_file"
        if ! "$update_file"; then
            log_error "Update script execution failed"
            return 1
        fi
        log_message "INFO" "Update script executed successfully"
    fi
    
    if [ -n "$update_num" ]; then
        echo "$update_num" > "$LAST_UPDATE_FILE"
    fi
    
    return 0
}

# Handle direct file updates (for .new files)
if [[ $1 == *.new ]]; then
    execute_update "$1"
    exit $?
fi

# Look for numbered updates
for update_file in "$UPDATES_DIR"/update*; do
    # Skip if no files found
    [ -e "$update_file" ] || continue
    
    # Extract update number from filename
    if [[ $update_file =~ update([0-9]+) ]]; then
        update_num="${BASH_REMATCH[1]}"
        
        # Check if this update should be executed
        if [ "$update_num" -gt "$last_update" ]; then
            log_message "INFO" "Found new update: $update_file"
            
            # Execute the update
            if ! execute_update "$update_file" "$update_num"; then
                log_error "Update $update_num failed, stopping update process"
                exit 1
            fi
        fi
    fi
done

log_message "INFO" "All updates completed"
exit 0
