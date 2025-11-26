#!/usr/bin/env bash
# Module to install Syncthing via its official Debian repository.

echo "Installing Syncthing for file synchronization..."

# 1. Add the release PGP keys
echo "Adding Syncthing PGP key..."
mkdir -p /etc/apt/keyrings
curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg

# 2. Add the "stable-v2" channel to the APT sources
echo "Adding Syncthing stable-v2 repository to sources.list.d..."
echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | tee /etc/apt/sources.list.d/syncthing.list

# 3. Update the package lists and install syncthing
echo "Updating package lists and installing syncthing..."
apt-get update
apt-get install -y syncthing

echo "Syncthing installation complete."