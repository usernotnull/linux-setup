#!/usr/bin/env bash
# Module to install ripgrep from the latest GitHub .deb release.

echo "Installing ripgrep (fast search tool)..."

APP_PACKAGE="ripgrep"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ ripgrep is already installed. Skipping."
    exit 0
fi

# Define variables
RIPGREP_REPO="BurntSushi/ripgrep"
ARCH="amd64"

# 2. Fetch the URL for the latest stable .deb release
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

# 3. Download the package
wget -q "$LATEST_DEB_URL"

# Get the actual downloaded filename for dpkg
DOWNLOADED_FILE=$(basename "$LATEST_DEB_URL")

# Ensure the filename ends with .deb (safety check)
if [[ "${DOWNLOADED_FILE}" != *.deb ]]; then
  echo "❌ Expected a .deb package but got: ${DOWNLOADED_FILE} — aborting."
  rm -f "$DOWNLOADED_FILE"
  exit 1
fi

# 4. Install the package using dpkg
dpkg -i "$DOWNLOADED_FILE"

# 5. Clean up the downloaded .deb file
rm -f "$DOWNLOADED_FILE"

echo "ripgrep installation complete."