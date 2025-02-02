#!/bin/sh

# Directory for node_exporter textfile collector
METRIC_DIR="/var/lib/node_exporter/textfile_collector"
METRIC_FILE="${METRIC_DIR}/client_connections.prom"

mkdir -p "$METRIC_DIR"

# Create temporary file
TMP_FILE=$(mktemp)

# Write metric headers
echo "# HELP openwrt_client_bytes_total Total bytes transferred by client" > "$TMP_FILE"
echo "# TYPE openwrt_client_bytes_total counter" >> "$TMP_FILE"
echo "# HELP openwrt_client_connection_time_seconds Connection time in seconds" >> "$TMP_FILE"
echo "# TYPE openwrt_client_connection_time_seconds gauge" >> "$TMP_FILE"
echo "# HELP openwrt_client_active_connections Number of active connections per client" >> "$TMP_FILE"
echo "# TYPE openwrt_client_active_connections gauge" >> "$TMP_FILE"

# Create temporary files for aggregation
BYTES_FILE=$(mktemp)
CONN_TIME_FILE=$(mktemp)

# Process conntrack entries
conntrack -L | while read -r line; do
    if echo "$line" | grep -q "src=192.168.2"; then
        src_ip=$(echo "$line" | grep -o 'src=192.168.2[.][0-9]*' | head -1 | cut -d= -f2)
        
        # Get bytes (both directions)
        in_bytes=$(echo "$line" | grep -o 'bytes=[0-9]*' | head -1 | cut -d= -f2)
        out_bytes=$(echo "$line" | grep -o 'bytes=[0-9]*' | tail -1 | cut -d= -f2)
        
        # Sum up bytes per IP
        echo "${src_ip} ${in_bytes:-0} in" >> "$BYTES_FILE"
        echo "${src_ip} ${out_bytes:-0} out" >> "$BYTES_FILE"
        
        # Get connection state and time
        if echo "$line" | grep -q "ESTABLISHED"; then
            conn_time=$(echo "$line" | grep -o '[0-9]* ESTABLISHED' | cut -d' ' -f1)
            echo "${src_ip} ${conn_time:-0} ESTABLISHED" >> "$CONN_TIME_FILE"
        elif echo "$line" | grep -q "TIME_WAIT"; then
            conn_time=$(echo "$line" | grep -o '[0-9]* TIME_WAIT' | cut -d' ' -f1)
            echo "${src_ip} ${conn_time:-0} TIME_WAIT" >> "$CONN_TIME_FILE"
        fi
    fi
done

# Aggregate and output bytes metrics
sort "$BYTES_FILE" | awk '
{
    if ($3 == "in") bytes_in[$1] += $2
    else if ($3 == "out") bytes_out[$1] += $2
}
END {
    for (ip in bytes_in) {
        printf "openwrt_client_bytes_total{ip=\"%s\",direction=\"in\"} %d\n", ip, bytes_in[ip]
        printf "openwrt_client_bytes_total{ip=\"%s\",direction=\"out\"} %d\n", ip, bytes_out[ip]
    }
}' >> "$TMP_FILE"

# Aggregate and output connection time metrics
sort "$CONN_TIME_FILE" | awk '
{
    if ($3 == "ESTABLISHED") {
        if ($2 > est[$1]) est[$1] = $2
    }
    else if ($3 == "TIME_WAIT") {
        if ($2 > twait[$1]) twait[$1] = $2
    }
}
END {
    for (ip in est)
        printf "openwrt_client_connection_time_seconds{ip=\"%s\",state=\"ESTABLISHED\"} %d\n", ip, est[ip]
    for (ip in twait)
        printf "openwrt_client_connection_time_seconds{ip=\"%s\",state=\"TIME_WAIT\"} %d\n", ip, twait[ip]
}' >> "$TMP_FILE"

# Add active connections count
echo "# Active connections per client" >> "$TMP_FILE"
for ip in $(conntrack -L | grep -o 'src=192.168.2[.][0-9]*' | cut -d= -f2 | sort -u); do
    count=$(conntrack -L | grep "src=$ip" | wc -l)
    echo "openwrt_client_active_connections{ip=\"$ip\"} $count" >> "$TMP_FILE"
done

# Cleanup temp files
rm -f "$BYTES_FILE" "$CONN_TIME_FILE"

# Atomically update the metrics file
mv "$TMP_FILE" "$METRIC_FILE"