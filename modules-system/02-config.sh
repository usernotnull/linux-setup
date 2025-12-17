#!/usr/bin/env bash
# Module to configure system services and apply fixes.

echo "Starting system configuration..."

# Enable TLP (Power Management) Service
# echo "Enabling TLP service to start on boot..."
# systemctl enable tlp

# Remove conflicting audio package (fixes issue with playing audio)
# echo "Removing gstreamer1.0-vaapi (Audio fix)..."
# apt remove -y gstreamer1.0-vaapi

# --- Firewall Configuration (System Protection) ---
echo "Configuring UFW firewall rules for Syncthing access (System Protection)..."
# Allow Syncthing's default TCP port for synchronization
echo "Allowing TCP port 22000 (Syncthing Synchronization)..."
ufw allow 22000/tcp
# Allow Syncthing's default UDP port for discovery
echo "Allowing UDP port 21027 (Syncthing Discovery)..."
ufw allow 21027/udp

echo "Setting default file associations… [skipped]"

# xdg-mime default vlc.desktop \
#     video/mp4 \
#     video/x-matroska \
#     video/webm \
#     video/quicktime \
#     video/avi \
#     video/mpeg \
#     video/x-ms-wmv \
#     video/x-ms-asf \
#     video/3gpp \
#     video/3gpp2 \
#     video/mp2t \
#     audio/mpeg \
#     audio/flac \
#     audio/wav \
#     audio/ogg \
#     audio/mp4 \
#     audio/midi

echo "System configuration complete."
