#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Installs Visual Studio Code from official Microsoft .deb package
#
# USAGE:       sudo ./install_vscode.sh
#
# REQUIREMENTS:
#   - Must be run as root (or with sudo)
#   - wget must be available
#   - Debian-based system (Ubuntu, Debian, etc.)
#   - Internet connection
#
# NOTES:
#   - Downloads the latest stable VS Code .deb package
#   - Automatically resolves dependencies via apt
#   - Skips installation if VS Code is already installed
#   - Cleans up temporary files on completion or interruption
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="code"                    # Package name in dpkg/apt
DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
TEMP_DIR="/tmp"                       # Directory for temporary downloads
DOWNLOADED_FILE="$TEMP_DIR/vscode_latest_amd64.deb"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_PACKAGE="📦"
ICON_DOWNLOAD="⬇️"
ICON_INSTALL="⚙️"

# === CLEANUP HANDLER ===
cleanup() {
    if [ -f "$DOWNLOADED_FILE" ]; then
        rm -f "$DOWNLOADED_FILE"
        info "$ICON_CLEAN" "Cleaned up temporary file"
    fi
}

# Set up cleanup on exit and interruption
trap cleanup EXIT
trap 'echo; warn "Installation interrupted by user"; exit 130' INT TERM

# === HEADER ===
hr
log "$ICON_START" "Visual Studio Code Installer"
info "$ICON_PACKAGE" "Package: $APP_PACKAGE"
hr
echo

# === VALIDATIONS ===

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root. Please use sudo."
fi

# Check for required commands
command -v wget >/dev/null 2>&1 || die "wget is not installed. Install it with: apt install wget"
command -v dpkg >/dev/null 2>&1 || die "dpkg is not available. This script requires a Debian-based system."
command -v apt >/dev/null 2>&1 || die "apt is not available. This script requires a Debian-based system."

# Check if VS Code is already installed
# Use grep with redirect instead of -q to avoid issues with set -e
if dpkg -s "$APP_PACKAGE" 2>/dev/null | grep "Status: install ok installed" > /dev/null; then
    success "$ICON_SUCCESS" "Visual Studio Code is already installed"

    # Show installed version
    installed_version=$(dpkg -s "$APP_PACKAGE" 2>/dev/null | grep "^Version:" | awk '{print $2}')
    info "$ICON_PACKAGE" "Installed version: $installed_version"

    exit 0
fi

# === MAIN LOGIC ===

# Download VS Code package
log "$ICON_DOWNLOAD" "Downloading VS Code .deb package..."
info "$ICON_SEARCH" "Source: $DOWNLOAD_URL"

if wget --progress=bar:force:noscroll -O "$DOWNLOADED_FILE" "$DOWNLOAD_URL" 2>&1; then
    success "$ICON_DOWNLOAD" "Download completed"
else
    die "Failed to download VS Code package"
fi

# Verify downloaded file
if [ ! -f "$DOWNLOADED_FILE" ]; then
    die "Downloaded file not found: $DOWNLOADED_FILE"
fi

file_size=$(stat -c %s "$DOWNLOADED_FILE" 2>/dev/null || stat -f %z "$DOWNLOADED_FILE" 2>/dev/null)
if [ "$file_size" -lt 1000000 ]; then
    die "Downloaded file is suspiciously small (${file_size} bytes). Download may have failed."
fi

info "$ICON_PACKAGE" "Package size: $(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size} bytes")"

# Install the package
log "$ICON_INSTALL" "Installing VS Code package..."

if dpkg -i "$DOWNLOADED_FILE" 2>&1; then
    success "$ICON_INSTALL" "Package installed successfully"
else
    warn "dpkg installation completed with warnings (likely missing dependencies)"
fi

# Fix any missing dependencies
log "$ICON_INSTALL" "Resolving dependencies..."

if apt --fix-broken install -y > /dev/null 2>&1; then
    success "$ICON_INSTALL" "Dependencies resolved"
else
    die "Failed to resolve dependencies. Run 'apt --fix-broken install' manually."
fi

# Verify installation
if dpkg -s "$APP_PACKAGE" 2>/dev/null | grep "Status: install ok installed" > /dev/null; then
    installed_version=$(dpkg -s "$APP_PACKAGE" 2>/dev/null | grep "^Version:" | awk '{print $2}')

    echo
    hr
    success "$ICON_SUCCESS" "Visual Studio Code installation completed"
    info "$ICON_PACKAGE" "Installed version: $installed_version"
    info "💡" "Launch VS Code by running: code"
    hr
else
    die "Installation verification failed. VS Code may not be properly installed."
fi
