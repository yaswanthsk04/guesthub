# GuestHub Update System Documentation

## Overview
The update system consists of two parts:
1. Regular file updates (handled by checker.py and executor.sh)
2. Core component updates (handled by numbered update scripts)

## Regular Update System

### Components
- **checker.py**: Monitors and detects changes in:
  - opennds-exporter.py
  - prometheus-config.yml
  - docker-compose.yml

- **executor.sh**: Handles the update process for:
  - Docker-related files (batch mode)
  - Service files
  - Regular updates

### Update Flow
1. checker.py checks GitHub (v0.6.0 branch) every 5 minutes
2. If updates found:
   - Creates .new files
   - Groups updates (docker vs others)
   - Calls executor.sh
3. executor.sh:
   - Creates backups
   - Handles service restarts
   - Updates files
   - Verifies changes

## Core Component Updates

### When to Use
Use this when updating:
- checker.py
- executor.sh

### Update Script Template
```bash
#!/bin/sh
# Save as updates/updateX (where X is next number)

# Download new versions
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/update/update-checker.py -O /tmp/checker.py.new
wget https://raw.githubusercontent.com/yaswanthsk04/guesthub_v0.1.0/v0.6.0/scripts/update/update-executor.sh -O /tmp/executor.sh.new

# Create delayed update script
cat > /tmp/delayed_update.sh << 'EOF'
#!/bin/sh

# Safety checks
if ls /usr/local/monitoring/*/*.new 1> /dev/null 2>&1; then
    logger -t "delayed-update" "Updates in progress, will retry in 5 minutes"
    exit 0
fi

if pgrep -f "docker-compose" > /dev/null || pgrep -f "update-executor.sh" > /dev/null; then
    logger -t "delayed-update" "Operations in progress, will retry in 5 minutes"
    exit 0
fi

# Backup and update
backup_dir="/usr/local/monitoring/backups/$(date +%Y%m%d)"
mkdir -p "$backup_dir"

/etc/init.d/update-checker stop
sleep 2
pkill -f "checker.py"

cp /usr/local/monitoring/update-system/checker.py "$backup_dir/checker.py.$(date +%H%M%S).bak"
cp /usr/local/monitoring/update-system/executor.sh "$backup_dir/executor.sh.$(date +%H%M%S).bak"

mv /tmp/checker.py.new /usr/local/monitoring/update-system/checker.py
mv /tmp/executor.sh.new /usr/local/monitoring/update-system/executor.sh
chmod 755 /usr/local/monitoring/update-system/checker.py
chmod 755 /usr/local/monitoring/update-system/executor.sh

/etc/init.d/update-checker start

if [ $? -eq 0 ]; then
    crontab -l | grep -v "delayed_update.sh" | crontab -
    rm -- "$0"
    logger -t "delayed-update" "Core components updated successfully"
fi
EOF

chmod 755 /tmp/delayed_update.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /tmp/delayed_update.sh") | crontab -
```

## Directory Structure
```
/usr/local/monitoring/
├── update-system/
│   ├── checker.py
│   └── executor.sh
├── docker/
│   ├── docker-compose.yml
│   └── prometheus/
│       └── config.yml
├── exporters/
│   └── opennds.py
├── updates/
│   └── updateX
├── backups/
│   └── YYYYMMDD/
└── state/
    └── last_update
```

## Best Practices

1. Regular Updates:
   - Let checker.py handle them automatically
   - Don't modify files directly

2. Core Updates:
   - Copy template to updates/updateX
   - Test in safe environment first
   - Let delayed script handle timing

3. Monitoring:
   - Check /var/log/update-checker.log
   - Watch for update messages
   - Monitor service status
