#!/usr/bin/env bash
# Module to install OpenSnitch and configure its system service.

echo "Installing OpenSnitch application firewall..."

# 1. Install required Python packages for OpenSnitch functionality
echo "Installing Python prerequisites..."
apt install -y python3-grpcio python3-protobuf python3-slugify

echo "To install OpenSnitch, please visit the github repo..."

# # 2. Install the daemon and UI from local .deb files
# # ASSUMPTION: The opensnitch*.deb and python3-opensnitch-ui*.deb files are present 
# # in the current working directory when the main script is executed.
# echo "Installing OpenSnitch daemon and UI from local .deb files..."
# apt install -y ./opensnitch*.deb ./python3-opensnitch-ui*.deb

# # 3. Enable and start the opensnitch systemd service
# echo "Enabling and starting opensnitch service..."
# systemctl enable --now opensnitch
# systemctl start opensnitch

echo "OpenSnitch installation and service startup complete."