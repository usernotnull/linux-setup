#!/usr/bin/env bash
# Module to install Espanso (Wayland) via .deb package. Runs as root.

set -euo pipefail

echo "Starting Espanso (Wayland) SUDO installation (1/2)..."

# 1. Check if Espanso is already installed
if command -v espanso >/dev/null 2>&1; then
    echo "✅ Espanso is already installed. Skipping."
    exit 0
fi

# 2. Define variables
DOWNLOAD_URL="https://github.com/espanso/espanso/releases/latest/download/espanso-debian-wayland-amd64.deb" 
DOWNLOAD_FILE="/tmp/espanso-latest.deb"

wget -qO "$DOWNLOAD_FILE" "$DOWNLOAD_URL"

# 3. Install the package
apt install -y "$DOWNLOAD_FILE"
sudo setcap "cap_dac_override+p" $(which espanso) # https://espanso.org/docs/install/linux/#adding-the-required-capabilities

# 4. Clean up
rm -f "$DOWNLOAD_FILE"

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Register & Start Espanso service as USER'
echo 'Run the below command in another terminal:'
echo '>>>'
echo "espanso service register; espanso start"
echo '<<<'
echo 'When done, press [ENTER] to continue the script.'
echo '========================================================================'

read -r PAUSE
echo 'Installation to be continued in user-apps...'
echo 'Espanso installation complete.'

