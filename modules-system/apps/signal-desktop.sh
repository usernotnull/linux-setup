#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Signal Desktop messenger via official APT repository
#
# USAGE:       sudo ./install-signal.sh
#
# REQUIREMENTS:
#   - Must be run with sudo/root privileges
#   - Active internet connection
#   - Debian/Ubuntu-based system with apt
#   - wget, gpg commands available
#
# NOTES:
#   - Skips installation if Signal Desktop is already installed
#   - Adds official Signal repository to APT sources
#   - Safely handles existing repository configuration
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="signal-desktop"                                    # Package name in APT
REPO_FILE="/etc/apt/sources.list.d/signal-desktop.sources"    # APT sources file location
KEYRING_FILE="/usr/share/keyrings/signal-desktop-keyring.gpg" # GPG keyring location
SIGNING_KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
SOURCES_URL="https://updates.signal.org/static/desktop/apt/signal-desktop.sources"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_SIGNAL="💬"
ICON_KEY="🔑"

# === HEADER ===
hr
log "$ICON_START" "Signal Desktop Installation"
info "$ICON_SIGNAL" "Package: $APP_PACKAGE"
hr
echo

# === VALIDATIONS ===
# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    die "This script must be run with sudo or as root"
fi

# Check for required commands
command -v wget >/dev/null 2>&1 || die "wget command not found. Install it with: apt install wget"
command -v gpg >/dev/null 2>&1 || die "gpg command not found. Install it with: apt install gnupg"
command -v apt >/dev/null 2>&1 || die "apt command not found. This script requires a Debian/Ubuntu-based system"

# === MAIN LOGIC ===

# Check if Signal Desktop is already installed
if dpkg -l | grep "^ii.*${APP_PACKAGE}" > /dev/null 2>&1; then
    success "$ICON_SUCCESS" "Signal Desktop is already installed. Skipping installation."
    exit 0
fi

# Add repository if not already configured
if [ ! -f "$REPO_FILE" ]; then
    log "$ICON_KEY" "Configuring Signal Desktop repository..."

    # Create temporary files for key and sources
    temp_keyring=$(mktemp) || die "Failed to create temporary keyring file"
    temp_sources=$(mktemp) || die "Failed to create temporary sources file"
    trap 'rm -f "$temp_keyring" "$temp_sources"' EXIT

    # Download and install signing key
    info "$ICON_KEY" "Downloading Signal Desktop signing key..."
    if wget -q -O- "$SIGNING_KEY_URL" | gpg --dearmor > "$temp_keyring" 2>/dev/null; then
        install -m 644 "$temp_keyring" "$KEYRING_FILE" || die "Failed to install keyring"
        success "$ICON_KEY" "Signing key installed successfully"
    else
        die "Failed to download or process signing key"
    fi

    # Download and install repository sources file
    info "$ICON_FOLDER" "Adding repository to APT sources..."
    if wget -q -O "$temp_sources" "$SOURCES_URL"; then
        install -m 644 "$temp_sources" "$REPO_FILE" || die "Failed to install sources file"
        success "$ICON_FOLDER" "Repository added successfully"
    else
        die "Failed to download repository sources file"
    fi
else
    info "$ICON_FOLDER" "Signal repository already configured"
fi

# Update package database and install Signal Desktop
log "$ICON_SIGNAL" "Updating package database..."
if apt update -qq 2>&1; then
    success "$ICON_SUCCESS" "Package database updated"
else
    die "Failed to update package database"
fi

log "$ICON_SIGNAL" "Installing Signal Desktop..."
if apt install -y "$APP_PACKAGE" 2>&1 | grep -v "^$" > /dev/null; then
    success "$ICON_SUCCESS" "Signal Desktop installed successfully"
else
    die "Failed to install Signal Desktop"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Signal Desktop installation complete!"
info "$ICON_SIGNAL" "You can now launch Signal Desktop from your applications menu"
hr
