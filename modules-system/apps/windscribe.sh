#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs or updates Windscribe VPN Desktop App from the latest
#              GitHub release
#
# USAGE:       ./install-windscribe.sh
#
# REQUIREMENTS:
#   - curl must be available for GitHub API access
#   - wget must be available for downloading .deb package
#   - sudo/root privileges for package installation
#   - dpkg and apt-get for Debian-based systems
#   - Internet connection to access GitHub releases
#
# NOTES:
#   - Automatically detects installed version and skips if already latest
#   - Downloads appropriate .deb package for amd64 architecture
#   - Excludes CLI-only package in favor of desktop app
#   - Cleans up temporary files automatically
#   - Fixes missing dependencies after installation
#   - Windscribe service may need to be started after installation
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="windscribe"                      # Package name to check/install
WINDSCRIBE_REPO="Windscribe/Desktop-App"      # GitHub repository
ARCH="amd64"                                  # Target architecture

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_DOWNLOAD="⬇️"
ICON_VERSION="🔢"
ICON_PACKAGE="📦"
ICON_VPN="🔒"

# === HEADER ===
hr
log "$ICON_START" "Starting Windscribe VPN installer"
info "$ICON_PACKAGE" "Package: $APP_PACKAGE"
info "$ICON_VERSION" "Repository: $WINDSCRIBE_REPO"
info "🖥️" "Architecture: $ARCH"
hr
echo

# === VALIDATIONS ===
# Check for required commands
command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
command -v wget >/dev/null 2>&1 || die "wget is required but not installed"
command -v dpkg >/dev/null 2>&1 || die "dpkg is required (Debian-based system only)"
command -v apt-get >/dev/null 2>&1 || die "apt-get is required (Debian-based system only)"

# Check for sufficient privileges
if [ "$EUID" -ne 0 ]; then
    warn "This script requires root privileges for package installation"
    die "Please run with sudo: sudo $0"
fi

# === MAIN LOGIC ===

# Fetch latest release tag
log "$ICON_SEARCH" "Checking latest Windscribe release..."
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${WINDSCRIBE_REPO}/releases/latest" 2>/dev/null | \
  grep '"tag_name":' | cut -d '"' -f 4 || echo "")

if [ -z "$LATEST_TAG" ]; then
    die "Could not determine latest Windscribe release tag. Check internet connection."
fi

LATEST_VERSION="${LATEST_TAG#v}"
info "$ICON_VERSION" "Latest available version: $LATEST_VERSION"

# Check currently installed version
INSTALLED_VERSION=""
if dpkg -s "${APP_PACKAGE}" > /dev/null 2>&1; then
    INSTALLED_VERSION=$(dpkg -s "${APP_PACKAGE}" 2>/dev/null | grep '^Version:' | awk '{print $2}' || echo "")
    info "$ICON_VERSION" "Currently installed version: $INSTALLED_VERSION"

    # Normalize versions by stripping any Debian revision suffix (e.g., '-1')
    NORMALIZED_INSTALLED_VERSION="${INSTALLED_VERSION%%-*}"
    NORMALIZED_LATEST_VERSION="${LATEST_VERSION%%-*}"

    if [ "$NORMALIZED_INSTALLED_VERSION" = "$NORMALIZED_LATEST_VERSION" ]; then
        success "$ICON_SUCCESS" "$APP_PACKAGE is already at the latest version ($INSTALLED_VERSION)"
        exit 0
    fi
    info "🔄" "Update available: $INSTALLED_VERSION → $LATEST_VERSION"
else
    info "$ICON_PACKAGE" "$APP_PACKAGE is not currently installed"
fi

# Fetch the .deb download URL (excluding CLI version)
log "$ICON_SEARCH" "Locating desktop app .deb package for $ARCH architecture..."
LATEST_DEB_URL=$(curl -fsSL "https://api.github.com/repos/${WINDSCRIBE_REPO}/releases/latest" 2>/dev/null | \
  grep "browser_download_url" | \
  grep "_${ARCH}\\.deb" | \
  grep -v "cli" | \
  head -n 1 | \
  cut -d '"' -f 4 || echo "")

if [ -z "$LATEST_DEB_URL" ]; then
    die "Could not find desktop app .deb package URL for $ARCH architecture"
fi

info "$ICON_DOWNLOAD" "Download URL: $LATEST_DEB_URL"

# Download package to /tmp (accessible by _apt user)
TEMP_DEB=$(mktemp /tmp/windscribe.XXXXXX.deb)
# Set permissions so _apt user can access the file
chmod 644 "$TEMP_DEB"
trap 'rm -f "$TEMP_DEB"' EXIT  # Ensure cleanup on exit

log "$ICON_DOWNLOAD" "Downloading Windscribe package..."
if ! wget -q --show-progress -O "$TEMP_DEB" "$LATEST_DEB_URL"; then
    die "Failed to download Windscribe package"
fi

if [ ! -s "$TEMP_DEB" ]; then
    die "Downloaded file is empty: $TEMP_DEB"
fi

# Install the package
log "$ICON_PACKAGE" "Installing Windscribe..."
dpkg -i "$TEMP_DEB" >/dev/null 2>&1 || true

# Fix missing dependencies
log "$ICON_CLEAN" "Resolving dependencies..."
if apt-get install -f -y >/dev/null 2>&1; then
    success "$ICON_SUCCESS" "Dependencies resolved successfully"
else
    warn "Failed to resolve dependencies"
fi

# Verify installation
if command -v windscribe-cli >/dev/null 2>&1; then
    INSTALLED_WS_VERSION=$(dpkg -s "${APP_PACKAGE}" 2>/dev/null | grep '^Version:' | awk '{print $2}')
    success "$ICON_SUCCESS" "Windscribe successfully installed (version: $INSTALLED_WS_VERSION)"
else
    die "Installation completed but 'windscribe' command not found"
fi

# === FOOTER ===
echo
hr
success "$ICON_VPN" "Windscribe VPN installation complete"
info "💡" "Usage: windscribe [command]"
info "🚀" "To start: windscribe connect"
info "📚" "Documentation: https://github.com/Windscribe/Desktop-App"
hr
