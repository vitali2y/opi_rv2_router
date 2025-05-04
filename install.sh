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
option domain-name-servers 8.8.8.8, 8.8.4.4;

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
F=/etc/systemd/system/create_ap.service
cat > $F <<EOF
[Unit]
Description=Orange Pi RV2 AP Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/create_ap -m nat wlan0 end0 wifiname wifipass
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

FTMP=$F.tmp
sed "s/wifiname/$1/g" $F > $FTMP && mv $FTMP $F
sed "s/wifipass/$2/g" $F > $FTMP && mv $FTMP $F
echo "WiFi hotspot: "$1" / "$2

echo "Enabling services..."
systemctl daemon-reload
systemctl enable router.service
systemctl enable isc-dhcp-server
systemctl enable create_ap

echo "Making IP forwarding persistent..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "Saving iptables rules..."
netfilter-persistent save

# echo "Disabling IPv6 on LAN interface..."
# echo "net.ipv6.conf.end1.disable_ipv6=1" >> /etc/sysctl.conf
# sysctl -p

echo "Restarting services..."
systemctl restart networking
systemctl restart router.service
systemctl restart isc-dhcp-server
systemctl restart create_ap

# systemctl stop NetworkManager
# systemctl disable NetworkManager

echo ""
echo "Setup completed successfully: Orange Pi RV2 is now configured as a router!"
echo "WAN (Internet): end0"
echo "LAN (Local): end1 (192.168.10.1)"
echo "On connected PC: configure DHCP manually (IP: 192.168.10.10, netmask: 255.255.255.0, gateway: 192.168.10.1, DNS: 192.168.10.1,8.8.8.8), connect cable to router's end1 port!"
echo "Enjoy!"
echo "P. S. Do not forget to reboot both PC and router, and change default password for 'orangepi' user!"
