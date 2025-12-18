#!/usr/bin/env bash
# Module to install Espanso (Wayland) via .deb package. Runs as root.

set -euo pipefail

echo "Starting Espanso (Wayland) installation..."

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

echo 'Espanso installation complete.'

