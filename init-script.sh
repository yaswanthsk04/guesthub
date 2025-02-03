#!/bin/sh

# Configure network settings
echo "Configuring LAN IP"
uci set network.lan.ipaddr='192.168.98.1'        # LAN Gateway IP
uci set network.lan.netmask='255.255.254.0'      # Subnet mask to allow 510 IPs
uci commit network
/etc/init.d/network restart

# Configure DHCP settings
echo "Configuring DHCP"
uci set dhcp.lan.start='11'        # DHCP starts from 192.168.98.11
uci set dhcp.lan.limit='500'       # Total IPs: 500 (192.168.98.11 to 192.168.99.254)
uci set dhcp.lan.leasetime='6h'    # Lease time of 6 hours
uci commit dhcp

# Configure static DHCP reservation
echo "Configuring AP IP reservation"
uci add dhcp host
uci set dhcp.@host[-1].mac='5C:A6:E6:D8:CC:B2'   # 5c:a6:e6:d8:cc:b2 mac of tp link
uci set dhcp.@host[-1].ip='192.168.98.2'         # Reserved IP
uci set dhcp.@host[-1].name='AP1 | TP-LINK'    # Optional name
uci commit dhcp
/etc/init.d/dnsmasq restart

echo "About to reboot the system to apply changes"
sleep 5
reboot