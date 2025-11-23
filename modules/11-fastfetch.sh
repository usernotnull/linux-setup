#!/usr/bin/env bash
# Module to install fastfetch from the latest GitHub .deb release.

echo "Installing fastfetch (system information tool)..."

# Define variables
FASTFETCH_REPO="fastfetch-cli/fastfetch"
ARCH_FILE="fastfetch-linux-amd64.deb"

# 1. Fetch the URL for the latest stable .deb release
echo "Fetching latest fastfetch release URL for ${ARCH_FILE}..."
LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/${FASTFETCH_REPO}/releases/latest" | \
  grep "browser_download_url.*${ARCH_FILE}" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  sed 's/^[[:space:]]*//')

if [ -z "$LATEST_DEB_URL" ]; then
    echo "❌ Could not find the latest fastfetch .deb URL. Aborting fastfetch installation."
    exit 1
fi

echo "Found release: ${LATEST_DEB_URL}"

# 2. Download the package
echo "Downloading fastfetch .deb package..."
wget -q "$LATEST_DEB_URL"

# Get the actual downloaded filename for dpkg (should be fastfetch-linux-amd64.deb)
DOWNLOADED_FILE=$(basename "$LATEST_DEB_URL")

# 3. Install the package using dpkg
echo "Installing ${DOWNLOADED_FILE} using dpkg..."
sudo dpkg -i "$DOWNLOADED_FILE"

# 4. Clean up the downloaded .deb file
echo "Cleaning up downloaded package..."
rm -f "$DOWNLOADED_FILE"

echo "fastfetch installation complete."