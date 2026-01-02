#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Tuta Mail (Tutanota) AppImage for the current user.
#
# USAGE:       ./install-tuta.sh
#
# REQUIREMENTS:
#   - wget
#   - Internet connection
#
# NOTES:
#   - Installs to $HOME/Applications by default.
#   - Skips download if the file already exists.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_NAME="tuta_mail.appimage"
INSTALL_ROOT="$HOME/Applications"               # Base directory for optional software
INSTALL_DIR="$INSTALL_ROOT"                     # Directory for this specific app
APP_PATH="$INSTALL_DIR/$APP_NAME"               # Full path to the executable
DOWNLOAD_URL="https://app.tuta.com/desktop/tutanota-desktop-linux.AppImage"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_APP="📧"
ICON_DOWNLOAD="⬇️"

# === HEADER ===
hr
log "$ICON_START" "Starting Tuta Mail Installer"
info "$ICON_FOLDER" "Install location: $INSTALL_DIR"
hr
echo

# === VALIDATIONS ===
# Check for required tools
command -v wget >/dev/null 2>&1 || die "wget is required but not installed."

# === MAIN LOGIC ===

# 1. Prepare Installation Directory
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR" || die "Failed to create directory: $INSTALL_DIR"
    log "$ICON_FOLDER" "Created installation directory."
fi

# 2. Check for existing installation
if [ -f "$APP_PATH" ]; then
    # Validate it's actually executable
    if [ -x "$APP_PATH" ]; then
        success "$ICON_SUCCESS" "Tuta Mail is already installed at: $APP_PATH"
        exit 0
    else
        warn "File exists but is not executable. Fixing permissions..."
        chmod u+x "$APP_PATH"
        success "$ICON_SUCCESS" "Fixed permissions for existing installation."
        exit 0
    fi
fi

# 3. Download AppImage
# Setup trap to clean up partial downloads if interrupted
cleanup() {
    if [ -f "$APP_PATH" ] && [ ! -x "$APP_PATH" ]; then
        echo
        warn "Download interrupted. Cleaning up partial file..."
        rm -f "$APP_PATH"
    fi
}
trap 'cleanup; exit 130' INT TERM

log "$ICON_DOWNLOAD" "Downloading Tuta Mail..."
info "🔗" "Source: $DOWNLOAD_URL"

# Download with wget (using -q --show-progress for cleaner output)
if wget -q --show-progress -O "$APP_PATH" "$DOWNLOAD_URL"; then
    echo # Newline after progress bar
else
    rm -f "$APP_PATH" # Ensure cleanup on failure
    die "Download failed."
fi

# 4. Finalize Installation
if [ -f "$APP_PATH" ]; then
    log "🔧" "Making AppImage executable..."
    chmod u+x "$APP_PATH"
else
    die "File not found after download: $APP_PATH"
fi

# === FOOTER ===
success "$ICON_SUCCESS" "Tuta Mail installed successfully!"
info "$ICON_APP" "Run it via: $APP_PATH"
