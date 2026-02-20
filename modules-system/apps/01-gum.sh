#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Gum (charmbracelet CLI tool) via its official APT repository
#              (Idempotent - safe to run multiple times)
#
# USAGE:       sudo ./install-gum.sh
#
# REQUIREMENTS:
#   - Must be run as root or with sudo
#   - curl must be installed
#   - gpg must be installed
#   - APT package manager (Debian/Ubuntu-based systems)
#   - Internet connection to download repository keys and packages
#
# NOTES:
#   - Script is idempotent - safe to run multiple times
#   - Adds official Charm repository if not already configured
#   - Skips installation if Gum is already installed
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="gum"                               # Package name in APT
REPO_FILE="/etc/apt/sources.list.d/charm.list"  # Repository source file location
KEYRING_DIR="/etc/apt/keyrings"                 # Keyring directory
KEYRING_FILE="$KEYRING_DIR/charm.gpg"           # GPG keyring file location
KEYRING_URL="https://repo.charm.sh/apt/gpg.key" # GPG key URL
REPO_LINE="deb [signed-by=$KEYRING_FILE] https://repo.charm.sh/apt/ * *"

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
log "$ICON_START" "Starting Gum Installation"
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
command -v gpg >/dev/null 2>&1 || die "gpg is required but not installed. Install it with: apt install gnupg"
command -v dpkg >/dev/null 2>&1 || die "dpkg is required but not found. Are you on a Debian/Ubuntu-based system?"
command -v apt >/dev/null 2>&1 || die "apt is required but not found. Are you on a Debian/Ubuntu-based system?"

# Check internet connectivity
if ! curl -s --head --max-time 5 https://charm.sh >/dev/null; then
    die "No internet connection detected. Please check your network connection."
fi

# === MAIN LOGIC ===

# Check if package is already installed
if dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" >/dev/null; then
    success "$ICON_SUCCESS" "Gum is already installed"

    # Show current version
    installed_version=$(dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}')
    if [ -n "$installed_version" ]; then
        info "$ICON_PACKAGE" "Installed version: $installed_version"
    fi

    exit 0
fi

log "$ICON_SEARCH" "Gum not found. Proceeding with installation..."
echo

# Configure repository if not already present
repo_configured=false
if [ -f "$REPO_FILE" ]; then
    if grep -q "repo.charm.sh/apt" "$REPO_FILE" >/dev/null; then
        repo_configured=true
        info "$ICON_REPO" "Charm repository already configured"
        echo
    fi
fi

if [ "$repo_configured" = false ]; then
    log "$ICON_REPO" "Configuring Charm repository..."

    # Create keyrings directory if it doesn't exist
    if [ ! -d "$KEYRING_DIR" ]; then
        log "$ICON_FOLDER" "Creating keyrings directory..."
        mkdir -p "$KEYRING_DIR" || die "Failed to create $KEYRING_DIR"
        success "$ICON_FOLDER" "Created $KEYRING_DIR"
    fi

    # Download and install the GPG key
    log "$ICON_DOWNLOAD" "Downloading GPG key..."
    if curl -fsSL "$KEYRING_URL" | gpg --dearmor -o "$KEYRING_FILE" 2>/dev/null; then
        success "$ICON_KEY" "GPG key installed"
    else
        die "Failed to download and install GPG key from $KEYRING_URL"
    fi

    # Add repository to sources list
    log "$ICON_REPO" "Adding repository to sources list..."
    if echo "$REPO_LINE" >"$REPO_FILE"; then
        success "$ICON_REPO" "Repository configuration installed"
    else
        die "Failed to write repository configuration to $REPO_FILE"
    fi

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

# Install Gum
log "$ICON_PACKAGE" "Installing ${APP_PACKAGE}..."
if apt install -y "${APP_PACKAGE}" >/dev/null 2>&1; then
    success "$ICON_SUCCESS" "Gum installed successfully"

    # Show installed version
    if installed_version=$(dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}'); then
        info "$ICON_PACKAGE" "Installed version: $installed_version"
    fi
else
    die "Failed to install ${APP_PACKAGE}"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Gum installation completed successfully"
info "💡" "You can now use gum in your terminal. Try: gum --help"
hr
