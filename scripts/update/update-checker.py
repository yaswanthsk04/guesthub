#!/usr/bin/env python3
import requests
import hashlib
import time
import os
import logging
import subprocess
from datetime import datetime, timedelta
from prometheus_client import start_http_server, Gauge, Counter

# Prometheus metrics
UPDATE_STATUS = Gauge('update_status', 'Update status by component (1=success, 0=failure)', ['component'])
LAST_UPDATE_TIME = Gauge('last_update_timestamp', 'Last update timestamp by component', ['component'])
UPDATE_COUNT = Counter('update_total', 'Total number of updates', ['component', 'status'])

# Setup logging with detailed timestamp format
class CustomFormatter(logging.Formatter):
    def format(self, record):
        record.message = record.getMessage()
        timestamp = self.formatTime(record, self.datefmt)
        return f"[{timestamp}] update-checker: {record.levelname} - {record.message}"

# Configure logging
logger = logging.getLogger('update-checker')
logger.setLevel(logging.INFO)

# File handler
file_handler = logging.FileHandler('/var/log/update-checker.log')
file_handler.setFormatter(CustomFormatter(datefmt='%Y-%m-%d %H:%M:%S'))
logger.addHandler(file_handler)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setFormatter(CustomFormatter(datefmt='%Y-%m-%d %H:%M:%S'))
logger.addHandler(console_handler)

# Configuration
GITHUB_RAW_BASE = "https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0"
LOCAL_BASE_DIR = "/usr/local/monitoring"
CHECK_INTERVAL = 300  # Check every 5 minutes (safe for GitHub API limits)

# Files to monitor in order of update priority
UPDATE_ORDER = [
    'services/opennds-exporter.py',          # 1st: Update service components
    'scripts/setup/verify-setup.sh',         # 2nd: Update verify-setup script
    'config/prometheus-config.yml',           # 3rd: Update monitoring config
    'config/loki-config.yml',                # 4th: Update Loki config
    'config/promtail-config.yml',            # 5th: Update Promtail config
    'config/docker-compose.yml'              # 6th: Update container setup last
]

# Map files to their local paths
CORE_FILES = {
    'config/docker-compose.yml': f'{LOCAL_BASE_DIR}/docker/docker-compose.yml',
    'config/prometheus-config.yml': f'{LOCAL_BASE_DIR}/docker/prometheus/prometheus-config.yml',
    'config/loki-config.yml': f'{LOCAL_BASE_DIR}/docker/loki/loki-config.yml',
    'config/promtail-config.yml': f'{LOCAL_BASE_DIR}/docker/promtail/promtail-config.yml',
    'services/opennds-exporter.py': f'{LOCAL_BASE_DIR}/exporters/opennds-exporter.py',
    'scripts/setup/verify-setup.sh': f'{LOCAL_BASE_DIR}/setup-verify/verify-setup.sh'
}

# State file for tracking updates
LAST_UPDATE_FILE = f"{LOCAL_BASE_DIR}/state/last_update"

# Ensure directories exist
os.makedirs(f"{LOCAL_BASE_DIR}/docker/prometheus", exist_ok=True)
os.makedirs(f"{LOCAL_BASE_DIR}/docker/loki", exist_ok=True)
os.makedirs(f"{LOCAL_BASE_DIR}/docker/promtail", exist_ok=True)

def ensure_updates_dir():
    """Ensure updates directory exists"""
    os.makedirs(f"{LOCAL_BASE_DIR}/updates", exist_ok=True)

def set_permissions(filepath):
    """Set appropriate permissions based on file type"""
    try:
        # Base permission: owner read/write, group read, others read (644)
        base_perm = 0o644
        
        # For scripts: owner read/write/execute, group read/execute, others read/execute (755)
        if filepath.endswith(('.py', '.sh')) or '/init.d/' in filepath:
            base_perm = 0o755
            
        # For directories: add execute permission to allow traversal
        if os.path.isdir(filepath):
            base_perm = 0o755
            
        os.chmod(filepath, base_perm)
        logger.info(f"Set permissions {oct(base_perm)} for {filepath}")
        return True
    except Exception as e:
        logger.error(f"Error setting permissions for {filepath}: {e}")
        return False

def download_file(github_path, local_path):
    """Download a file from GitHub"""
    url = f"{GITHUB_RAW_BASE}/{github_path}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        # Create parent directories if they don't exist
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        set_permissions(os.path.dirname(local_path))
        
        # Save the file
        with open(local_path, 'w') as f:
            f.write(response.text)
        
        # Set appropriate permissions
        set_permissions(local_path)
        
        return True
    except Exception as e:
        logger.error(f"Error downloading {github_path}: {e}")
        return False

def update_metrics(component, success):
    """Update Prometheus metrics for a component"""
    status_value = 1 if success else 0
    UPDATE_STATUS.labels(component=component).set(status_value)
    LAST_UPDATE_TIME.labels(component=component).set(time.time())
    UPDATE_COUNT.labels(component=component, status='success' if success else 'failure').inc()

def check_core_files():
    """Check and update core configuration files in specific order"""
    updates_needed = False
    docker_updates = []  # Track docker-related updates
    other_updates = []   # Track other updates
    
    # First pass: Check all files and prepare updates
    for github_path in UPDATE_ORDER:
        local_path = CORE_FILES[github_path]
        try:
            # Get remote content
            response = requests.get(f"{GITHUB_RAW_BASE}/{github_path}")
            response.raise_for_status()
            remote_content = response.text
            
            # Compare with local content
            try:
                with open(local_path, 'r') as f:
                    local_content = f.read()
                if remote_content != local_content:
                    logger.info(f"Update found for {github_path}")
                    # Create temporary file
                    tmp_path = f"{local_path}.new"
                    os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
                    with open(tmp_path, 'w') as f:
                        f.write(remote_content)
                    logger.info(f"Created temporary file at {tmp_path}")
                    
                    # Group updates
                    if github_path in ['config/docker-compose.yml', 'config/prometheus-config.yml', 'config/loki-config.yml', 'config/promtail-config.yml']:
                        docker_updates.append(tmp_path)
                    else:
                        other_updates.append(tmp_path)
                    
                    updates_needed = True
            except FileNotFoundError:
                logger.error(f"Local file not found: {local_path}")
        except Exception as e:
            logger.error(f"Error checking {github_path}: {e}")
    
    # Second pass: Execute updates in proper order
    if docker_updates:
        # If we have docker-related updates, handle them together
        logger.info("Processing docker-related updates together...")
        # Execute all docker updates in a single batch
        result = subprocess.run(
            [f"{LOCAL_BASE_DIR}/update-system/executor.sh", "--batch"] + docker_updates,
            capture_output=True,
            text=True
        )
        if result.stdout:
            logger.info(f"Update executor output: {result.stdout}")
        if result.stderr:
            # Split on both newlines and container operations
            stderr_text = result.stderr
            for split_term in ['container', '\n']:
                stderr_text = stderr_text.replace(split_term, '\n' + split_term)
            stderr_lines = [line.strip() for line in stderr_text.splitlines() if line.strip()]
            
            for line in stderr_lines:
                # Check for normal docker operations (expanded list)
                if any(normal_msg in line.lower() for normal_msg in 
                      ['stopping', 'stopped', 'removing', 'removed', 'starting', 'started', 'done', 'creating', 'created']):
                    logger.info(f"Docker compose: {line}")
                else:
                    logger.error(f"Update executor error: {line}")
        success = result.returncode == 0
        if not success:
            logger.error(f"Update failed for docker-related updates")
        # Update metrics for docker components
        for update_file in docker_updates:
            component = os.path.basename(update_file).replace('.new', '')
            update_metrics(component, success)
    
    # Handle other updates normally
    for update_file in other_updates:
        result = subprocess.run(
            [f"{LOCAL_BASE_DIR}/update-system/executor.sh", update_file],
            capture_output=True,
            text=True
        )
        if result.stdout:
            logger.info(f"Update executor output: {result.stdout}")
            if result.stderr:
                # Split on both newlines and container operations
                stderr_text = result.stderr
                for split_term in ['container', '\n']:
                    stderr_text = stderr_text.replace(split_term, '\n' + split_term)
                stderr_lines = [line.strip() for line in stderr_text.splitlines() if line.strip()]
                
                for line in stderr_lines:
                    # Check for normal docker operations (expanded list)
                    if any(normal_msg in line.lower() for normal_msg in 
                          ['stopping', 'stopped', 'removing', 'removed', 'starting', 'started', 'done', 'creating', 'created']):
                        logger.info(f"Docker compose: {line}")
                    else:
                        logger.error(f"Update executor error: {line}")
        success = result.returncode == 0
        if not success:
            logger.error(f"Update failed for {update_file}")
        # Update metrics for this component
        component = os.path.basename(update_file).replace('.new', '')
        update_metrics(component, success)

def get_remote_updates():
    """Get list of update files from GitHub"""
    try:
        # Using GitHub API to list directory contents
        api_url = "https://api.github.com/repos/yaswanthsk04/guesthub_v0.1.0/contents/updates"
        response = requests.get(api_url)
        
        # If directory doesn't exist, no updates available
        if response.status_code == 404:
            logger.info("No updates directory found in repository")
            return []
            
        response.raise_for_status()
        
        updates = []
        for item in response.json():
            if item['type'] == 'file' and item['name'].startswith('update'):
                try:
                    # Extract number from update name (e.g., 'update123' -> 123)
                    update_num = int(item['name'].replace('update', ''))
                    updates.append((update_num, item['name']))
                except ValueError:
                    continue
        
        # Sort updates by number
        updates.sort(key=lambda x: x[0])
        return [name for num, name in updates]
    except requests.exceptions.RequestException as e:
        if hasattr(e.response, 'status_code') and e.response.status_code == 404:
            logger.info("No updates directory found in repository")
        else:
            logger.error(f"Error checking for updates: {e}")
        return []
    except Exception as e:
        logger.error(f"Unexpected error checking for updates: {e}")
        return []

def check_update_scripts():
    """Check and download update scripts"""
    try:
        remote_updates = get_remote_updates()
        for update in remote_updates:
            local_path = f"{LOCAL_BASE_DIR}/updates/{update}"
            if not os.path.exists(local_path):
                logger.info(f"Found new update: {update}")
                if download_file(f"updates/{update}", local_path):
                    subprocess.run([f"{LOCAL_BASE_DIR}/update-system/executor.sh", local_path])
    except Exception as e:
        logger.error(f"Error checking update scripts: {e}")

def check_for_updates():
    """Check both core files and update scripts"""
    logger.info("Starting update check cycle...")
    ensure_updates_dir()
    
    # Check core files
    logger.info("Checking core files for updates...")
    check_core_files()
    
    # Check update scripts
    logger.info("Checking for update scripts...")
    check_update_scripts()
    
    logger.info("Update check cycle completed")

def cleanup_temp_files():
    """Clean up any leftover .new files"""
    for file_path in CORE_FILES.values():
        new_file = f"{file_path}.new"
        if os.path.exists(new_file):
            try:
                os.remove(new_file)
                logger.info(f"Cleaned up leftover file: {new_file}")
            except Exception as e:
                logger.error(f"Failed to clean up {new_file}: {e}")

def main():
    logger.info("********************************")
    logger.info("Update checker starting - Version 0.1.0 - TEST UPDATE")
    logger.info("********************************")
    
    # Start Prometheus metrics server
    start_http_server(9300)
    logger.info("Started Prometheus metrics server on port 9300")
    
    # Initial cleanup of any leftover files
    cleanup_temp_files()
    
    # Initialize metrics for all components
    for github_path in UPDATE_ORDER:
        component = os.path.basename(CORE_FILES[github_path])
        local_path = CORE_FILES[github_path]
        # Set initial status based on file existence
        initial_status = 1 if os.path.exists(local_path) else 0
        UPDATE_STATUS.labels(component=component).set(initial_status)
        LAST_UPDATE_TIME.labels(component=component).set(time.time())
        UPDATE_COUNT.labels(component=component, status='success' if initial_status else 'failure').inc()
    
    # Perform immediate check on startup
    check_for_updates()
    cleanup_temp_files()  # Clean up after initial check
    
    # Enter the main update loop
    while True:
        try:
            next_check = datetime.now() + timedelta(seconds=CHECK_INTERVAL)
            logger.info(f"Next check scheduled for: {next_check.strftime('%Y-%m-%d %H:%M:%S')}")
            time.sleep(CHECK_INTERVAL)
            
            check_for_updates()
            cleanup_temp_files()  # Clean up after each update cycle
        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            time.sleep(60)  # Wait a minute before retrying on error

if __name__ == "__main__":
    main()
