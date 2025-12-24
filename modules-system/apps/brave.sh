#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Brave Browser via its official APT repository
#              (Idempotent - safe to run multiple times)
#
# USAGE:       sudo ./install-brave.sh
#
# REQUIREMENTS:
#   - Must be run as root or with sudo
#   - curl must be installed
#   - APT package manager (Debian/Ubuntu-based systems)
#   - Internet connection to download repository keys and packages
#
# NOTES:
#   - Script is idempotent - safe to run multiple times
#   - Adds official Brave repository if not already configured
#   - Skips installation if Brave is already installed
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="brave-browser"                                                # Package name in APT
REPO_FILE="/etc/apt/sources.list.d/brave-browser-release.sources"        # Repository source file location
KEYRING_FILE="/usr/share/keyrings/brave-browser-archive-keyring.gpg"     # GPG keyring file location
KEYRING_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
REPO_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser.sources"

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
ICON_KEY="🔑"
ICON_REPO="📚"
ICON_PACKAGE="📦"

# === HEADER ===
hr
log "$ICON_START" "Starting Brave Browser Installation"
info "$ICON_PACKAGE" "Package: $APP_PACKAGE"
hr
echo

# === VALIDATIONS ===
# Check if running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

# Check for required commands
command -v curl >/dev/null 2>&1 || die "curl is required but not installed. Install it with: apt install curl"
command -v dpkg >/dev/null 2>&1 || die "dpkg is required but not found. Are you on a Debian/Ubuntu-based system?"
command -v apt >/dev/null 2>&1 || die "apt is required but not found. Are you on a Debian/Ubuntu-based system?"

# Check internet connectivity
if ! curl -s --head --max-time 5 https://brave.com > /dev/null; then
    die "No internet connection detected. Please check your network connection."
fi

# === MAIN LOGIC ===

# Check if package is already installed
if dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" > /dev/null; then
    success "$ICON_SUCCESS" "Brave Browser is already installed"

    # Show current version
    installed_version=$(dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}')
    if [ -n "$installed_version" ]; then
        info "$ICON_PACKAGE" "Installed version: $installed_version"
    fi

    exit 0
fi

log "$ICON_SEARCH" "Brave Browser not found. Proceeding with installation..."
echo

# Configure repository if not already present
if [ ! -f "${REPO_FILE}" ]; then
    log "$ICON_REPO" "Configuring Brave Browser repository..."

    # Download and install the GPG keyring
    log "$ICON_DOWNLOAD" "Downloading GPG keyring..."
    if curl -fsSL "${KEYRING_URL}" -o "${KEYRING_FILE}"; then
        success "$ICON_KEY" "GPG keyring installed"
    else
        die "Failed to download GPG keyring from ${KEYRING_URL}"
    fi

    # Download the repository source file
    log "$ICON_DOWNLOAD" "Downloading repository configuration..."
    if curl -fsSL "${REPO_URL}" -o "${REPO_FILE}"; then
        success "$ICON_REPO" "Repository configuration installed"
    else
        die "Failed to download repository configuration from ${REPO_URL}"
    fi

    echo
else
    info "$ICON_REPO" "Brave repository already configured"
    echo
fi

# Update package database
log "$ICON_DOWNLOAD" "Updating package database..."
if apt update -qq 2>&1 | grep -qi "error"; then
    warn "Package database update encountered issues. Continuing anyway..."
else
    success "$ICON_SUCCESS" "Package database updated"
fi
echo

# Install Brave Browser
log "$ICON_PACKAGE" "Installing ${APP_PACKAGE}..."
if apt install -y "${APP_PACKAGE}" > /dev/null 2>&1; then
    success "$ICON_SUCCESS" "Brave Browser installed successfully"

    # Show installed version
    if installed_version=$(dpkg -l | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}'); then
        info "$ICON_PACKAGE" "Installed version: $installed_version"
    fi
else
    die "Failed to install ${APP_PACKAGE}"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Brave Browser installation completed successfully"
info "💡" "You can now launch Brave from your applications menu or by running: brave-browser"
hr
