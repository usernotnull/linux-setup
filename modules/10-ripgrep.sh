#!/usr/bin/env bash
# Module to install ripgrep from the latest GitHub .deb release.

echo "Installing ripgrep (fast search tool)..."

# Define variables
RIPGREP_REPO="BurntSushi/ripgrep"
ARCH="amd64"
DEB_FILE="ripgrep_*.deb"

# 1. Fetch the URL for the latest stable .deb release
echo "Fetching latest ripgrep release URL for ${ARCH}..."
LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/${RIPGREP_REPO}/releases/latest" | \
  grep "browser_download_url.*${ARCH}\.deb" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  sed 's/^[[:space:]]*//')

if [ -z "$LATEST_DEB_URL" ]; then
    echo "❌ Could not find the latest ripgrep .deb URL. Aborting ripgrep installation."
    exit 1
fi

echo "Found release: ${LATEST_DEB_URL}"

# 2. Download the package
echo "Downloading ripgrep .deb package..."
wget -q "$LATEST_DEB_URL"

# Get the actual downloaded filename for dpkg
DOWNLOADED_FILE=$(basename "$LATEST_DEB_URL")

# 3. Install the package using dpkg
echo "Installing ${DOWNLOADED_FILE} using dpkg..."
sudo dpkg -i "$DOWNLOADED_FILE"

# 4. Clean up the downloaded .deb file
echo "Cleaning up downloaded package..."
rm -f "$DOWNLOADED_FILE"

echo "ripgrep installation complete."