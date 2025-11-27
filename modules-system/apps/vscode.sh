#!/usr/bin/env bash
# Module to install Visual Studio Code (official .deb package). Runs as root.

set -euo pipefail

echo "Starting Visual Studio Code installation (Official .deb)..."

# Define variables
APP_PACKAGE="code" # The package name used by dpkg/apt

# 1. Check if VS Code is already installed using the robust dpkg -s command.
# This checks for the exact status 'Status: install ok installed', which confirms 
# the package is fully and correctly set up on the system.
if dpkg -s "${APP_PACKAGE}" 2>/dev/null | grep -q "Status: install ok installed"; then
    echo "✅ Visual Studio Code is already installed. Skipping."
    exit 0
fi

# 2. Define the download URL and temporary file paths
# This URL redirects to the latest stable .deb file.
DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
DOWNLOADED_FILE="/tmp/vscode_latest_amd64.deb"

echo "Downloading VS Code .deb package..."
# Download the file to /tmp using -qO (quiet output to file)
wget -qO "$DOWNLOADED_FILE" "$DOWNLOAD_URL"

# 3. Install the package
echo "Installing VS Code using dpkg..."
# dpkg -i installs the package but does not automatically resolve dependencies
dpkg -i "$DOWNLOADED_FILE"

# 4. Fix dependencies
# This command is crucial. It forces APT to check for and install any missing 
# dependencies that 'dpkg -i' may have left unresolved.
echo "Running apt --fix-broken install to satisfy dependencies..."
apt --fix-broken install -y

# 5. Clean up
echo "Cleaning up temporary file..."
rm -f "$DOWNLOADED_FILE"

echo "Visual Studio Code installation complete."