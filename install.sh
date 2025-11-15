#!/bin/bash

# Orange Pi RV2 Router Setup Script

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!" >&2
  exit 1
fi

if [ -z "$2" ]; then
    echo "Usage: sudo ./install.sh <wifi_name> <wifi_password>"
    exit 2
fi

echo "Starting Orange Pi RV2 Router Setup..."

echo "System update & installing required packages..."
apt update -y
apt upgrade -y
apt install -y iptables-persistent isc-dhcp-server

echo "Configuring DNS..."
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=208.67.222.222 208.67.220.220
Domains=~.
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
EOF

systemctl restart systemd-resolved

cat > /etc/network/interfaces <<EOF
# Loopback
auto lo
iface lo inet loopback

# WAN interface (end0 - DHCP from ISP)
auto end0
iface end0 inet dhcp

# LAN interface (end1 - static)
auto end1
iface end1 inet static
  address 192.168.10.1
  netmask 255.255.255.0
EOF

echo "Setting up DHCP server..."
cat > /etc/dhcp/dhcpd.conf <<EOF
option domain-name "local";
option domain-name-servers 192.168.10.1, 8.8.8.8;

default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.168.10.0 netmask 255.255.255.0 {
  range 192.168.10.100 192.168.10.200;
  option routers 192.168.10.1;
  option broadcast-address 192.168.10.255;
}
EOF

echo 'INTERFACESv4="end1"' > /etc/default/isc-dhcp-server

echo "Creating router service..."
cat > /etc/systemd/system/router.service <<EOF
[Unit]
Description=Orange Pi RV2 Router Service
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes

# Enable IP forwarding
ExecStart=/bin/sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Configure NAT (end0 = WAN)
ExecStart=/sbin/iptables -t nat -A POSTROUTING -o end0 -j MASQUERADE
ExecStart=/sbin/iptables -A FORWARD -i end1 -o end0 -j ACCEPT
ExecStart=/sbin/iptables -A FORWARD -i end0 -o end1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow incoming traffic to LAN interface
ExecStart=/sbin/iptables -I INPUT -i end1 -j ACCEPT

# Stop commands
ExecStop=/bin/sh -c "echo 0 > /proc/sys/net/ipv4/ip_forward"
ExecStop=/sbin/iptables -t nat -D POSTROUTING -o end0 -j MASQUERADE
ExecStop=/sbin/iptables -D FORWARD -i end1 -o end0 -j ACCEPT
ExecStop=/sbin/iptables -D FORWARD -i end0 -o end1 -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=/sbin/iptables -D INPUT -i end1 -j ACCEPT

[Install]
WantedBy=multi-user.target
EOF

echo "WiFi Setup..."
cat > /etc/systemd/system/create_ap.service <<EOF
[Unit]
Description=Orange Pi RV2 AP Service
After=network.target router.service
Requires=router.service
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/create_ap -m nat wlan0 end0 $1 $2
ExecStop=/usr/local/bin/create_ap --stop wlan0

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling services..."
systemctl daemon-reload
systemctl enable router.service
systemctl enable isc-dhcp-server
systemctl enable create_ap.service

echo "Making IP forwarding persistent..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "Saving iptables rules..."
netfilter-persistent save
netfilter-persistent reload

# echo "Configuring WiFi regulatory domain..."
# echo 'REGDOMAIN=00' > /etc/default/crda  # 00 is world regulatory domain

echo "Restarting services..."
systemctl restart networking
systemctl restart router.service
systemctl restart isc-dhcp-server
sleep 3
systemctl restart create_ap.service

echo "Setting up robust DHCP renewal service for end0..."
cat << 'EOF' > /etc/systemd/system/fresh-dhcp-wan.service
[Unit]
Description=Force fresh DHCP on end0
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'dhclient -r end0 && sleep 2 && dhclient -nw end0'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fresh-dhcp-wan.service
echo "DHCP service 'fresh-dhcp-wan.service' installed and enabled"

echo ""
echo "Setup completed successfully: Orange Pi RV2 is now configured as a router!"
echo "WAN (Internet, right Ethernet port from top): end0"
echo "LAN (Local, left Ethernet port from top): end1 (192.168.10.1)"
echo "WiFi Hotspot: $1 / $2"
echo "On connected PC: configure DHCP manually (IP: 192.168.10.10, netmask: 255.255.255.0, gateway: 192.168.10.1, DNS: 192.168.10.1,8.8.8.8)"
echo "Enjoy!"
echo "P. S. Do not forget to reboot both PC and router, and change default password for 'orangepi' user!"
