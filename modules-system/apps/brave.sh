#!/usr/bin/env bash
# Module to install Brave Browser via its official APT repository (Idempotent). Runs as root.

echo "Starting Brave Browser installation..."

APP_PACKAGE="brave-browser"
REPO_FILE="/etc/apt/sources.list.d/brave-browser-release.sources"
KEYRING_FILE="/usr/share/keyrings/brave-browser-archive-keyring.gpg"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ Brave Browser is already installed. Skipping installation."
    exit 0
fi

# 2. Add repository only if the source file does not exist
if [ ! -f "${REPO_FILE}" ]; then
    # Download and install the keyring
    curl -fsSLo "${KEYRING_FILE}" https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

    # Download the repository source file
    curl -fsSLo "${REPO_FILE}" https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
else
    echo "Brave repository already configured. Skipping key and repo addition."
fi

# 3. Update your package database and install Brave Browser
echo "Updating package database and installing brave-browser..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Add the Sync Chain'
echo 'Open Brave > Settings > Sync'
echo '========================================================================'

read -r PAUSE
echo "Brave Browser installation complete."
