#!/bin/bash
# Module to configure system services and apply fixes.

echo "Starting system configuration…"

# Enable TLP (Power Management) Service
# echo "Enabling TLP service to start on boot…"
# systemctl enable tlp

# --- Firewall Configuration (System Protection) ---
echo "Configuring UFW firewall rules for Syncthing access (System Protection)…"
# Allow Syncthing's default TCP port for synchronization
echo "Allowing TCP port 22000 (Syncthing Synchronization)…"
ufw allow 22000/tcp
# Allow Syncthing's default UDP port for discovery
echo "Allowing UDP port 21027 (Syncthing Discovery)…"
ufw allow 21027/udp
ufw enable

# CUPS (Common Unix Printing System) suite automatically discovers and creates local print queues for remote CUPS printers on the network
# There have been recent security vulnerabilities discovered in CUPS.
# Since you don't need printing at all, disabling both services is a good idea for security.
echo "Disabling CUPS (Common Unix Printing System)"
sudo systemctl stop cups-browsed
sudo systemctl disable cups-browsed
sudo systemctl mask cups-browsed

sudo systemctl stop cups
sudo systemctl disable cups
sudo systemctl mask cups

# Avahi is a zero-configuration networking (zeroconf) implementation, including a system for multicast DNS service discovery. 
# It allows programs to publish and discover services and hosts running on a local network with no specific configuration.
sudo systemctl stop avahi-daemon.socket avahi-daemon.service
sudo systemctl disable avahi-daemon.socket avahi-daemon.service
# You can mask it. This links the unit files to /dev/null, making it impossible to start manually or automatically
sudo systemctl mask avahi-daemon.socket avahi-daemon.service

# ModemManager (Mobile broadband/SIM cards)
sudo systemctl stop --now ModemManager.service
sudo systemctl disable ModemManager.service
sudo systemctl mask ModemManager.service

echo "System configuration complete."
