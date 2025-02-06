#!/usr/bin/env python3
import time
import subprocess
from datetime import datetime
from prometheus_client import start_http_server, Gauge, Info, REGISTRY

# Define Prometheus metrics
# Info metric combines all client data into one metric for better table display
CLIENT_METRICS = Info('opennds_client_metrics', 'Combined client metrics', ['mac', 'ip'])

# Router-wide metrics remain as Gauges since they're single values
ROUTER_DOWNLOAD = Gauge('opennds_router_download_bytes_total', 'Total router download')
ROUTER_UPLOAD = Gauge('opennds_router_upload_bytes_total', 'Total router upload')

def parse_bytes(value):
    """
    Convert human-readable byte strings into numeric values.
    Examples: '1.5 kB' -> 1536, '500 B' -> 500
    """
    try:
        if 'kB' in value:
            # Convert kilobytes to bytes
            return float(value.split()[0]) * 1024
        return float(value.split()[0])
    except:
        return 0

def get_nds_data():
    """
    Retrieve and parse data from ndsctl status command.
    Returns tuple of (router_stats, client_data_list)
    """
    try:
        # Run ndsctl status command and get output
        nds_output = subprocess.check_output(['ndsctl', 'status']).decode('utf-8')
        lines = nds_output.split('\n')
        
        # Initialize data structures
        total_stats = {}  # Router-wide statistics
        clients_data = [] # List to hold per-client data
        current_client = None
        
        # Parse each line of the output
        for line in lines:
            line = line.strip()
            
            # Handle router-wide statistics
            if 'Total download:' in line:
                total_stats['total_download'] = line.split(':', 1)[1].split(';')[0].strip()
            elif 'Total upload:' in line:
                total_stats['total_upload'] = line.split(':', 1)[1].split(';')[0].strip()
            
            # Handle per-client data
            if line.startswith('Client ') and 'Type:' not in line:
                # New client section started
                if current_client:
                    clients_data.append(current_client)
                current_client = {}
            elif current_client is not None and ':' in line:
                # Parse client details
                key, value = [x.strip() for x in line.split(':', 1)]
                if key == 'Client Type':
                    current_client['type'] = value
                elif 'MAC:' in value:
                    # Split IP and MAC address
                    current_client['ip'] = value.split('MAC:')[0].strip()
                    current_client['mac'] = value.split('MAC:')[1].strip()
                elif key == 'State':
                    current_client['state'] = value
                elif key == 'Download this session':
                    current_client['download'] = value
                elif key == 'Upload this session':
                    current_client['upload'] = value
        
        # Add last client if exists
        if current_client:
            clients_data.append(current_client)
                
        return total_stats, clients_data
    except Exception as e:
        print(f"Error getting NDS data: {e}")
        return {}, []

def update_metrics():
    """
    Update all Prometheus metrics with fresh data.
    Clears old metrics and sets new values for all connected clients.
    """
    # Get fresh data from ndsctl
    total_stats, clients_data = get_nds_data()
    
    # Clear existing client metrics by unregistering and re-registering
    try:
        REGISTRY.unregister(CLIENT_METRICS)
    except KeyError:
        pass  # Ignore if metrics weren't registered yet
    
    # Re-register the metrics collector
    REGISTRY.register(CLIENT_METRICS)
    
    # Update router totals
    router_download = parse_bytes(total_stats.get('total_download', '0'))
    router_upload = parse_bytes(total_stats.get('total_upload', '0'))
    ROUTER_DOWNLOAD.set(router_download)
    ROUTER_UPLOAD.set(router_upload)
    
    # Update metrics for currently connected clients
    active_clients = set()  # Track currently active clients
    for client in clients_data:
        if client.get('mac') and client.get('ip'):
            mac = client['mac']
            ip = client['ip']
            active_clients.add(f"{mac}_{ip}")
            
            # Export all client metrics as a single info metric
            # This makes it easier to create tables in Grafana
            CLIENT_METRICS.labels(mac=mac, ip=ip).info({
                'download_bytes': str(parse_bytes(client['download'].split(';')[0])),
                'upload_bytes': str(parse_bytes(client['upload'].split(';')[0])),
                'state': client.get('state', 'Unknown'),
                'type': client.get('type', 'unknown'),
                'client_id': f"{mac}_{ip}",
                'last_seen': datetime.now().isoformat()
            })

def main():
    """
    Main function to start the Prometheus metrics server and update loop.
    """
    # Start Prometheus HTTP server
    start_http_server(9200)
    print("Prometheus metrics available on port 9200")
    
    try:
        # Main loop - update metrics every 15 seconds
        while True:
            update_metrics()
            time.sleep(15)
    except KeyboardInterrupt:
        print("\nExiting...")

if __name__ == '__main__':
    main()