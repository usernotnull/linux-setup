#!/usr/bin/env bash
# Module to install ripgrep from the latest GitHub .deb release.
# Checks installed version against latest release to prevent unnecessary re-downloads.

set -euo pipefail

echo "Installing ripgrep (fast search tool)..."

APP_PACKAGE="ripgrep"

# Define variables
RIPGREP_REPO="BurntSushi/ripgrep"
ARCH="amd64"

# 1. Determine latest stable release tag (strip leading 'v' if present)
LATEST_TAG=$(curl -s "https://api.github.com/repos/${RIPGREP_REPO}/releases/latest" | \
  grep '"tag_name":' | cut -d '"' -f 4)

if [ -z "$LATEST_TAG" ]; then
  echo "❌ Could not determine latest ripgrep release tag. Aborting."
  exit 1
fi

LATEST_VERSION="${LATEST_TAG#v}"
echo "Latest ripgrep version: ${LATEST_VERSION}"

# 2. Check installed version (if any) and normalize Debian revisions
INSTALLED_VERSION=""
if dpkg -s "${APP_PACKAGE}" >/dev/null 2>&1; then
  INSTALLED_VERSION=$(dpkg -s "${APP_PACKAGE}" | grep '^Version:' | cut -d ' ' -f 2)
  echo "Currently installed version: ${INSTALLED_VERSION}"

  # Normalize versions by stripping Debian revision suffix (e.g., '-1')
  NORMALIZED_INSTALLED_VERSION="${INSTALLED_VERSION%%-*}"
  NORMALIZED_LATEST_VERSION="${LATEST_VERSION%%-*}"

  if [ "${NORMALIZED_INSTALLED_VERSION}" == "${NORMALIZED_LATEST_VERSION}" ]; then
    echo "✅ ${APP_PACKAGE} is already at the latest version (${INSTALLED_VERSION}). Skipping."
    exit 0
  fi
  echo "🔄 Update available: ${INSTALLED_VERSION} -> ${LATEST_VERSION}"
else
  echo "ℹ️ ${APP_PACKAGE} is not installed. Proceeding with install of ${LATEST_VERSION}."
fi

# 3. Fetch the .deb browser_download_url for the desired arch
echo "Fetching latest ripgrep .deb URL for ${ARCH}..."
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

# 4. Download to a temp file and install
TEMP_DEB=$(mktemp /tmp/ripgrep.XXXXXX.deb)
echo "Downloading ripgrep from ${LATEST_DEB_URL}..."
wget -qO "$TEMP_DEB" "$LATEST_DEB_URL"

if [ ! -s "$TEMP_DEB" ]; then
  echo "❌ Download failed or file is empty: $TEMP_DEB"
  rm -f "$TEMP_DEB"
  exit 1
fi

echo "Installing ripgrep..."
dpkg -i "$TEMP_DEB"

# 5. Fix missing dependencies if any
echo "Checking for missing dependencies..."
apt-get install -f -y >/dev/null

# 6. Clean up
rm -f "$TEMP_DEB"

echo "ripgrep installation complete."
