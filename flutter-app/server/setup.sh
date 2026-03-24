#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install OpenVPN
sudo apt install openvpn easy-rsa -y

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Basic firewall rules
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo "Basic VPN setup complete"