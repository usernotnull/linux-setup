#!/usr/bin/env bash
# Module to install actions-for-nautilus from the latest GitHub stable .deb release.
# Checks installed version against latest release to prevent unnecessary re-downloads.

set -euo pipefail

echo "Installing actions-for-nautilus..."

# Define variables
REPO="bassmanitram/actions-for-nautilus"
APP_PACKAGE="actions-for-nautilus"

# 1. Fetch the latest STABLE release tag (excluding pre-releases)
# We use the GitHub API 'latest' endpoint which automatically excludes pre-releases unless specified.
# Then we extract the tag name (e.g., "v1.7.1").
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | \
  grep '"tag_name":' | \
  cut -d '"' -f 4)

if [ -z "$LATEST_TAG" ]; then
    echo "❌ Could not find the latest release tag for ${APP_PACKAGE}. Aborting."
    exit 1
fi

# Clean the tag (remove 'v' prefix if present) for version comparison
LATEST_VERSION="${LATEST_TAG#v}"

echo "Latest stable version found: ${LATEST_VERSION}"

# 2. Check installed version
INSTALLED_VERSION=""
if dpkg -s "${APP_PACKAGE}" >/dev/null 2>&1; then
    INSTALLED_VERSION=$(dpkg -s "${APP_PACKAGE}" | grep '^Version:' | cut -d ' ' -f 2)
    echo "Currently installed version: ${INSTALLED_VERSION}"

    # Compare versions
    if [ "${INSTALLED_VERSION}" == "${LATEST_VERSION}" ]; then
        echo "✅ ${APP_PACKAGE} is already at the latest version (${INSTALLED_VERSION}). Skipping."
        exit 0
    fi
    echo "🔄 Update available! (${INSTALLED_VERSION} -> ${LATEST_VERSION})"
else
    echo "ℹ️ ${APP_PACKAGE} is not installed."
fi

# 3. Fetch the download URL for the .deb file
# We look for the browser_download_url that ends in .deb within the latest release data.
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | \
  grep "browser_download_url.*\.deb" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  sed 's/^[[:space:]]*//')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Could not find a .deb download URL for release ${LATEST_TAG}. Aborting."
    exit 1
fi

echo "Downloading from: ${DOWNLOAD_URL}"

# 4. Download the package
# Create a temp file path using mktemp for safety
TEMP_DEB=$(mktemp /tmp/actions-for-nautilus.XXXXXX.deb)
wget -qO "$TEMP_DEB" "$DOWNLOAD_URL"

# 5. Install the package using dpkg
echo "Installing ${APP_PACKAGE}..."
dpkg -i "$TEMP_DEB"

# 6. Fix dependencies if needed
echo "Checking for missing dependencies..."
apt-get install -f -y >/dev/null

# 7. Clean up
rm -f "$TEMP_DEB"

echo "actions-for-nautilus installation complete."
