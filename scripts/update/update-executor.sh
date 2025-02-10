#!/bin/bash
# Update executor script
# This script looks for and executes numbered update files
# Note: Core component (checker and executor) updates are handled by update scripts

UPDATES_DIR="/usr/local/monitoring/updates"
LAST_UPDATE_FILE="/usr/local/monitoring/state/last_update"

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
    cd /usr/local/monitoring/docker || return 1
    
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

# Function to handle loki config updates
handle_loki() {
    local file="$1"
    log_message "INFO" "Updating loki config..."
    cd /usr/local/monitoring/docker || return 1
    
    # Ensure loki directory exists
    mkdir -p loki
    chmod 755 loki
    
    # Create backup
    create_backup "loki/loki-config.yml"
    
    # Stop all services
    log_message "INFO" "Stopping Docker services..."
    docker-compose down
    
    # Update file
    log_message "INFO" "Updating loki config file..."
    cp "$file" loki/loki-config.yml
    chmod 644 loki/loki-config.yml
    
    # Start all services
    log_message "INFO" "Starting Docker services..."
    docker-compose up -d
    
    # Verify services are running
    if docker-compose ps | grep -q "Up"; then
        log_message "INFO" "Loki configuration updated and services running successfully"
        return 0
    else
        log_error "Services failed to start after loki update"
        return 1
    fi
}

# Function to handle promtail config updates
handle_promtail() {
    local file="$1"
    log_message "INFO" "Updating promtail config..."
    cd /usr/local/monitoring/docker || return 1
    
    # Ensure promtail directory exists
    mkdir -p promtail
    chmod 755 promtail
    
    # Create backup
    create_backup "promtail/promtail-config.yml"
    
    # Stop all services
    log_message "INFO" "Stopping Docker services..."
    docker-compose down
    
    # Update file
    log_message "INFO" "Updating promtail config file..."
    cp "$file" promtail/promtail-config.yml
    chmod 644 promtail/promtail-config.yml
    
    # Start all services
    log_message "INFO" "Starting Docker services..."
    docker-compose up -d
    
    # Verify services are running
    if docker-compose ps | grep -q "Up"; then
        log_message "INFO" "Promtail configuration updated and services running successfully"
        return 0
    else
        log_error "Services failed to start after promtail update"
        return 1
    fi
}

# Function to handle prometheus config updates
handle_prometheus() {
    local file="$1"
    log_message "INFO" "Updating prometheus config..."
    cd /usr/local/monitoring/docker || return 1
    
    # Ensure prometheus directory exists
    mkdir -p prometheus
    chmod 755 prometheus
    
    # Create backup
    create_backup "prometheus/prometheus-config.yml"
    
    # Stop all services
    log_message "INFO" "Stopping Docker services..."
    docker-compose down
    
    # Update file
    log_message "INFO" "Updating prometheus config file..."
    cp "$file" prometheus/prometheus-config.yml
    chmod 644 prometheus/prometheus-config.yml
    
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
    create_backup "/usr/local/monitoring/exporters/opennds-exporter.py"
    
    # Stop service
    log_message "INFO" "Stopping OpenNDS exporter..."
    /etc/init.d/opennds-exporter stop
    
    # Update file
    log_message "INFO" "Updating opennds-exporter.py file..."
    cp "$file" /usr/local/monitoring/exporters/opennds-exporter.py
    chmod +x /usr/local/monitoring/exporters/opennds-exporter.py
    
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

# Function to handle verify-setup.sh updates
handle_verify_setup() {
    local file="$1"
    log_message "INFO" "Updating verify-setup script..."
    
    # Create backup
    create_backup "/usr/local/monitoring/setup-verify/verify-setup.sh"
    
    # Stop service
    log_message "INFO" "Stopping verify-setup service..."
    /etc/init.d/verify-setup stop
    
    # Update file
    log_message "INFO" "Updating verify-setup.sh file..."
    cp "$file" /usr/local/monitoring/setup-verify/verify-setup.sh
    chmod +x /usr/local/monitoring/setup-verify/verify-setup.sh
    
    # Start service
    log_message "INFO" "Starting verify-setup service..."
    /etc/init.d/verify-setup start
    
    # Verify service is running
    if /etc/init.d/verify-setup status | grep -q "running"; then
        log_message "INFO" "Verify-setup service updated and running successfully"
        return 0
    else
        log_error "Verify-setup service failed to start"
        return 1
    fi
}

# Function to handle batch docker updates
handle_docker_batch() {
    shift # Skip the --batch flag
    local files=("$@")
    
    cd /usr/local/monitoring/docker || return 1
    
    # Stop services once for batch update
    log_message "INFO" "Stopping Docker services for batch update..."
    docker-compose down
    
    # Process all files first
    for file in "${files[@]}"; do
        if [[ $file == *"docker-compose.yml"* ]]; then
            # Create backup
            create_backup "docker-compose.yml"
            
            # Update file
            log_message "INFO" "Updating docker-compose.yml file..."
            cp "$file" docker-compose.yml
            rm -f "$file"
        elif [[ $file == *"prometheus-config.yml"* ]]; then
            # Ensure prometheus directory exists
            mkdir -p prometheus
            chmod 755 prometheus
            
            # Create backup
            create_backup "prometheus/prometheus-config.yml"
            
            # Update file
            log_message "INFO" "Updating prometheus config file..."
            cp "$file" prometheus/prometheus-config.yml
            chmod 644 prometheus/prometheus-config.yml
            rm -f "$file"
        elif [[ $file == *"loki-config.yml"* ]]; then
            # Ensure loki directory exists
            mkdir -p loki
            chmod 755 loki
            
            # Create backup
            create_backup "loki/loki-config.yml"
            
            # Update file
            log_message "INFO" "Updating loki config file..."
            cp "$file" loki/loki-config.yml
            chmod 644 loki/loki-config.yml
            rm -f "$file"
        elif [[ $file == *"promtail-config.yml"* ]]; then
            # Ensure promtail directory exists
            mkdir -p promtail
            chmod 755 promtail
            
            # Create backup
            create_backup "promtail/promtail-config.yml"
            
            # Update file
            log_message "INFO" "Updating promtail config file..."
            cp "$file" promtail/promtail-config.yml
            chmod 644 promtail/promtail-config.yml
            rm -f "$file"
        fi
    done
    
    # Start services once after all updates
    log_message "INFO" "Starting Docker services..."
    docker-compose up -d
    
    # Verify services
    if docker-compose ps | grep -q "Up"; then
        log_message "INFO" "Services started successfully after batch update"
        return 0
    else
        log_error "Services failed to start after batch update"
        return 1
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
            "docker-compose.yml"|"prometheus-config.yml"|"loki-config.yml"|"promtail-config.yml")
                if [ "$is_batch" == "--batch" ]; then
                    handle_docker_batch "$update_file" "$is_batch"
                else
                    if [[ $base_name == "docker-compose.yml" ]]; then
                        handle_docker_compose "$update_file"
                    elif [[ $base_name == "prometheus-config.yml" ]]; then
                        handle_prometheus "$update_file"
                    elif [[ $base_name == "loki-config.yml" ]]; then
                        handle_loki "$update_file"
                    elif [[ $base_name == "promtail-config.yml" ]]; then
                        handle_promtail "$update_file"
                    fi
                fi
                ;;
            "opennds-exporter.py")
                handle_opennds_exporter "$update_file"
                ;;
            "verify-setup.sh")
                handle_verify_setup "$update_file"
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
if [[ $1 == "--batch" ]]; then
    handle_docker_batch "$@"
    exit $?
elif [[ $1 == *.new ]]; then
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
