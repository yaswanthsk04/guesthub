#!/usr/bin/env python3
import requests
import hashlib
import time
import os
import logging
import subprocess
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/update-checker.log'),
        logging.StreamHandler()
    ]
)

# Configuration
GITHUB_RAW_BASE = "https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/main"
LOCAL_BASE_DIR = "/usr/local/monitoring"
CHECK_INTERVAL = 300  # Check every 5 minutes (safe for GitHub API limits)

# Files to monitor in order of update priority
UPDATE_ORDER = [
    'config/docker-compose.yml',
    'config/prometheus-config.yml',
    'services/opennds-exporter.py',
    'scripts/update/update-executor.sh',  # Executor must update before checker
    'scripts/update/update-checker.py'    # Checker updates last
]

# Map files to their local paths
CORE_FILES = {
    'config/docker-compose.yml': f'{LOCAL_BASE_DIR}/docker-compose.yml',
    'config/prometheus-config.yml': f'{LOCAL_BASE_DIR}/prometheus/prometheus.yml',  # GitHub path -> local path
    'services/opennds-exporter.py': f'{LOCAL_BASE_DIR}/opennds-exporter.py',
    'scripts/update/update-checker.py': f'{LOCAL_BASE_DIR}/update-checker.py',
    'scripts/update/update-executor.sh': f'{LOCAL_BASE_DIR}/update-executor.sh'
}

# Ensure prometheus directory exists
os.makedirs(f"{LOCAL_BASE_DIR}/prometheus", exist_ok=True)

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
        logging.info(f"Set permissions {oct(base_perm)} for {filepath}")
        return True
    except Exception as e:
        logging.error(f"Error setting permissions for {filepath}: {e}")
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
        logging.error(f"Error downloading {github_path}: {e}")
        return False

def check_core_files():
    """Check and update core configuration files in specific order"""
    updates_needed = False
    
    # Check and update files in specified order
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
                    logging.info(f"Update found for {github_path}")
                    # Use update executor to handle the file update
                    tmp_path = f"{local_path}.new"
                    
                    # Ensure directory exists for the new file
                    os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
                    
                    # Write the new content
                    with open(tmp_path, 'w') as f:
                        f.write(remote_content)
                    
                    logging.info(f"Created temporary file at {tmp_path}")
                    
                    # Execute update and capture output
                    result = subprocess.run(
                        [f"{LOCAL_BASE_DIR}/update-executor.sh", tmp_path],
                        capture_output=True,
                        text=True
                    )
                    
                    # Log the output
                    if result.stdout:
                        logging.info(f"Update executor output: {result.stdout}")
                    if result.stderr:
                        logging.error(f"Update executor error: {result.stderr}")
                        
                    # Check if update was successful
                    if result.returncode != 0:
                        logging.error(f"Update failed for {github_path}")
                        continue
                    
                    logging.info(f"Update completed for {github_path}")
                    updates_needed = True
            except FileNotFoundError:
                logging.error(f"Local file not found: {local_path}")
        except Exception as e:
            logging.error(f"Error checking {github_path}: {e}")

def get_remote_updates():
    """Get list of update files from GitHub"""
    try:
        # Using GitHub API to list directory contents
        api_url = "https://api.github.com/repos/yaswanthsk04/guesthub_v0.1.0/contents/updates"
        response = requests.get(api_url)
        
        # If directory doesn't exist, no updates available
        if response.status_code == 404:
            logging.info("No updates directory found in repository")
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
            logging.info("No updates directory found in repository")
        else:
            logging.error(f"Error checking for updates: {e}")
        return []
    except Exception as e:
        logging.error(f"Unexpected error checking for updates: {e}")
        return []

def check_update_scripts():
    """Check and download update scripts"""
    try:
        remote_updates = get_remote_updates()
        for update in remote_updates:
            local_path = f"{LOCAL_BASE_DIR}/updates/{update}"
            if not os.path.exists(local_path):
                logging.info(f"Found new update: {update}")
                if download_file(f"updates/{update}", local_path):
                    subprocess.run([f"{LOCAL_BASE_DIR}/update-executor.sh", local_path])
    except Exception as e:
        logging.error(f"Error checking update scripts: {e}")

def check_for_updates():
    """Check both core files and update scripts"""
    ensure_updates_dir()
    check_core_files()
    check_update_scripts()

def main():
    logging.info("Update checker service started")
    while True:
        try:
            check_for_updates()
            time.sleep(CHECK_INTERVAL)
        except Exception as e:
            logging.error(f"Error in main loop: {e}")
            time.sleep(60)  # Wait a minute before retrying on error

if __name__ == "__main__":
    main()
