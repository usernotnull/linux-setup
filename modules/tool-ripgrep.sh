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
  # Match only browser_download_url entries that END in .deb (not .deb.sha256)
  grep -E "\"browser_download_url\": \".*_${ARCH}\\.deb\"" | \
  head -n 1 | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  sed 's/^[[:space:]]*//')

if [ -z "$LATEST_DEB_URL" ]; then
    echo "❌ Could not find the latest ripgrep .deb URL. Aborting ripgrep installation."
    exit 1
fi

# 2. Download the package
wget -q "$LATEST_DEB_URL"

# Get the actual downloaded filename for dpkg
DOWNLOADED_FILE=$(basename "$LATEST_DEB_URL")

# Ensure the filename ends with .deb (safety check)
if [[ "${DOWNLOADED_FILE}" != *.deb ]]; then
  echo "❌ Expected a .deb package but got: ${DOWNLOADED_FILE} — aborting."
  exit 1
fi

# 3. Install the package using dpkg
sudo dpkg -i "$DOWNLOADED_FILE"

# 4. Clean up the downloaded .deb file
rm -f "$DOWNLOADED_FILE"

echo "ripgrep installation complete."