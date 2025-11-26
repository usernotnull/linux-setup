#!/usr/bin/env bash
# Module to install Signal Desktop via its official APT repository.

echo "Installing Signal Desktop messenger..."

# 1. Install official public software signing key:
echo "Adding Signal Desktop signing key..."
# Download and dearmor the key
wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg
# Install the key into the system keyrings directory
cat signal-desktop-keyring.gpg | tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

# 2. Add the repository to the list of repositories:
echo "Adding Signal Desktop repository source..."
# Download the repository source file
wget -qO signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources
# Install the source file into the apt sources list directory
cat signal-desktop.sources | tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

# 3. Update your package database and install Signal:
echo "Updating package database and installing signal-desktop..."
apt update && apt install -y signal-desktop

# Cleanup downloaded temporary files in the current directory
rm -f signal-desktop-keyring.gpg signal-desktop.sources

echo "Signal Desktop installation complete."