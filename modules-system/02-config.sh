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

echo "System configuration complete."
