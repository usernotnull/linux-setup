#!/usr/bin/env bash
# Module to install Syncthing via its official Debian repository.

echo "Installing Syncthing for file synchronization..."

APP_PACKAGE="syncthing"
REPO_FILE="/etc/apt/sources.list.d/syncthing.list"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ Syncthing is already installed. Skipping installation."
    exit 0
fi

# 2. Add the release PGP keys and repository sources (only if repository file does not exist)
if [ ! -f "${REPO_FILE}" ]; then
    echo "Adding Syncthing PGP key..."
    mkdir -p /etc/apt/keyrings
    curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg

    echo "Adding Syncthing stable-v2 repository to sources.list.d..."
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | tee "${REPO_FILE}" >/dev/null
else
    echo "Syncthing repository already configured. Skipping key and repo addition."
fi

# 3. Update the package lists and install syncthing
echo "Updating package lists and installing syncthing..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Add your device to the sync network'
echo 'Visit: http://127.0.0.1:8384/'
echo 'Settings: Enable ONLY local discovery'
echo 'Add devices using format tcp://x.x.x.x:22000, etc…'
echo 'When done, press [ENTER] to continue the script.'
echo '========================================================================'

read -r PAUSE

echo "Syncthing installation complete."
