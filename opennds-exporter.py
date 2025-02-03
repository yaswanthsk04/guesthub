#!/usr/bin/env python3
import time
import subprocess
from datetime import datetime
from prometheus_client import start_http_server, Gauge

# Prometheus metrics
ROUTER_DOWNLOAD = Gauge('opennds_router_download_bytes_total', 'Total router download')
ROUTER_UPLOAD = Gauge('opennds_router_upload_bytes_total', 'Total router upload')
CLIENT_SESSION_DOWNLOAD = Gauge('opennds_client_session_download_bytes', 'Client session download', ['mac', 'ip'])
CLIENT_SESSION_UPLOAD = Gauge('opennds_client_session_upload_bytes', 'Client session upload', ['mac', 'ip'])
CLIENT_TOTAL_DOWNLOAD = Gauge('opennds_client_total_download_bytes', 'Client total download', ['mac', 'ip'])
CLIENT_TOTAL_UPLOAD = Gauge('opennds_client_total_upload_bytes', 'Client total upload', ['mac', 'ip'])
CLIENT_STATE = Gauge('opennds_client_state', 'Client authentication state', ['mac', 'ip', 'type'])

def parse_bytes(value):
    try:
        if 'kB' in value:
            return float(value.split()[0]) * 1024
        return float(value.split()[0])
    except:
        return 0

def get_nds_data():
    try:
        nds_output = subprocess.check_output(['ndsctl', 'status']).decode('utf-8')
        lines = nds_output.split('\n')
        
        total_stats = {}
        clients_data = []
        current_client = None
        
        for line in lines:
            line = line.strip()
            
            if 'Total download:' in line:
                total_stats['total_download'] = line.split(':', 1)[1].split(';')[0].strip()
            elif 'Total upload:' in line:
                total_stats['total_upload'] = line.split(':', 1)[1].split(';')[0].strip()
            
            if line.startswith('Client ') and 'Type:' not in line:
                if current_client:
                    clients_data.append(current_client)
                current_client = {}
            elif current_client is not None and ':' in line:
                key, value = [x.strip() for x in line.split(':', 1)]
                if key == 'Client Type':
                    current_client['type'] = value
                elif 'MAC:' in value:
                    current_client['ip'] = value.split('MAC:')[0].strip()
                    current_client['mac'] = value.split('MAC:')[1].strip()
                elif key == 'State':
                    current_client['state'] = value
                elif key == 'Download this session':
                    current_client['download'] = value
                elif key == 'Upload this session':
                    current_client['upload'] = value
        
        if current_client:
            clients_data.append(current_client)
                
        return total_stats, clients_data
    except Exception as e:
        print(f"Error getting NDS data: {e}")
        return {}, []

def update_metrics():
    total_stats, clients_data = get_nds_data()
    
    # Update router totals
    router_download = parse_bytes(total_stats.get('total_download', '0'))
    router_upload = parse_bytes(total_stats.get('total_upload', '0'))
    ROUTER_DOWNLOAD.set(router_download)
    ROUTER_UPLOAD.set(router_upload)
    
    # Clear client metrics (to remove disconnected clients)
    CLIENT_SESSION_DOWNLOAD._metrics.clear()
    CLIENT_SESSION_UPLOAD._metrics.clear()
    CLIENT_TOTAL_DOWNLOAD._metrics.clear()
    CLIENT_TOTAL_UPLOAD._metrics.clear()
    CLIENT_STATE._metrics.clear()
    
    # Update client metrics
    for client in clients_data:
        if client.get('mac') and client.get('ip'):
            mac = client['mac']
            ip = client['ip']
            
            # Session data
            download = parse_bytes(client['download'].split(';')[0])
            upload = parse_bytes(client['upload'].split(';')[0])
            
            CLIENT_SESSION_DOWNLOAD.labels(mac=mac, ip=ip).set(download)
            CLIENT_SESSION_UPLOAD.labels(mac=mac, ip=ip).set(upload)
            CLIENT_TOTAL_DOWNLOAD.labels(mac=mac, ip=ip).set(download)
            CLIENT_TOTAL_UPLOAD.labels(mac=mac, ip=ip).set(upload)
            CLIENT_STATE.labels(mac=mac, ip=ip, type=client.get('type', 'unknown')).set(
                1 if client.get('state') == 'Authenticated' else 0
            )

if __name__ == '__main__':
    # Start Prometheus HTTP server
    start_http_server(9200)
    print("Prometheus metrics available on port 9200")
    
    try:
        while True:
            update_metrics()
            time.sleep(15)
    except KeyboardInterrupt:
        print("\nExiting...")