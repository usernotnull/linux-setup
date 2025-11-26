#!/usr/bin/env bash
# Module to install fastfetch from the latest GitHub .deb release.

echo "Installing fastfetch (system information tool)..."

APP_PACKAGE="fastfetch"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ Fastfetch is already installed. Skipping."
    exit 0
fi

# Define variables
FASTFETCH_REPO="fastfetch-cli/fastfetch"
ARCH_FILE="fastfetch-linux-amd64.deb"

# 2. Fetch the URL for the latest stable .deb release
LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/${FASTFETCH_REPO}/releases/latest" | \
  grep "browser_download_url.*${ARCH_FILE}" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  sed 's/^[[:space:]]*//')

if [ -z "$LATEST_DEB_URL" ]; then
    echo "❌ Could not find the latest fastfetch .deb URL. Aborting fastfetch installation."
    exit 1
fi

# 3. Download the package
wget -q "$LATEST_DEB_URL"

# Get the actual downloaded filename for dpkg (should be fastfetch-linux-amd64.deb)
DOWNLOADED_FILE=$(basename "$LATEST_DEB_URL")

# 4. Install the package using dpkg (no sudo needed, script runs as root)
dpkg -i "$DOWNLOADED_FILE"

# 5. Clean up the downloaded .deb file
rm -f "$DOWNLOADED_FILE"

echo "fastfetch installation complete."