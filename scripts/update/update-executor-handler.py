#!/usr/bin/python3
import os
import sys
import shutil
import logging
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] update-executor-handler: %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler('/var/log/update-checker.log'),
        logging.StreamHandler()
    ]
)

def update_executor(new_file):
    """Handle update-executor.sh update"""
    base_dir = "/usr/local/monitoring"
    executor_path = f"{base_dir}/update-system/executor.sh"
    backup_dir = f"{base_dir}/backups/{datetime.now().strftime('%Y%m%d')}"
    
    try:
        # Create backup directory
        os.makedirs(backup_dir, exist_ok=True)
        
        # Move old executor to backup with timestamp
        if os.path.exists(executor_path):
            backup_name = f"update-executor.sh.{datetime.now().strftime('%H%M%S')}.bak"
            shutil.move(executor_path, f"{backup_dir}/{backup_name}")
            logging.info(f"Moved old executor to {backup_dir}/{backup_name}")
        
        # Move new file into place
        shutil.move(new_file, executor_path)
        os.chmod(executor_path, 0o755)
        logging.info("Moved new executor into place")
        
        return True
    except Exception as e:
        logging.error(f"Failed to update executor: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        logging.error("Usage: update-executor-handler.py <new_file_path>")
        sys.exit(1)
    
    new_file = sys.argv[1]
    if not os.path.exists(new_file):
        logging.error(f"New file not found: {new_file}")
        sys.exit(1)
    
    if update_executor(new_file):
        logging.info("Update executor handler completed successfully")
        sys.exit(0)
    else:
        logging.error("Update executor handler failed")
        sys.exit(1)
