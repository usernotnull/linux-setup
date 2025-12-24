#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs the Twitter Color Emoji Font (SVGinOT) for the current user.
#
# USAGE:       ./install-emoji-font.sh
#
# REQUIREMENTS:
#   - wget, tar, fc-cache
#   - Internet connection
#   - Write access to $HOME/.local/share/fonts
#
# NOTES:
#   - Installs version 15.1.0 by default.
#   - Safely cleans up downloaded artifacts on exit or interruption.
#   - Skips installation if the specific font file already exists.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
FONT_VERSION="15.1.0"
REPO_URL="https://github.com/13rac1/twemoji-color-font/releases/download/v${FONT_VERSION}"
TAR_FILENAME="TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}.tar.gz"
DOWNLOAD_URL="${REPO_URL}/${TAR_FILENAME}"

# Target directories
USER_FONT_DIR="$HOME/.local/share/fonts"
TARGET_FONT_FILE="$USER_FONT_DIR/TwitterColorEmoji-SVGinOT.ttf"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_FONT="🅰️"
ICON_DOWNLOAD="⬇️"
ICON_INSTALL="🔧"

# === HEADER ===
hr
log "$ICON_START" "Twitter Color Emoji Font Installer v${FONT_VERSION}"
info "$ICON_FOLDER" "Target: $USER_FONT_DIR"
hr
echo

# === VALIDATIONS ===
# Check for required tools
for cmd in wget tar fc-cache; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Required command not found: $cmd"
    fi
done

# === PRE-FLIGHT CHECKS ===
if [ -f "$TARGET_FONT_FILE" ]; then
    success "$ICON_SUCCESS" "Twitter Emoji Font is already installed."
    exit 0
fi

# Create font directory if it doesn't exist
if [ ! -d "$USER_FONT_DIR" ]; then
    info "$ICON_FOLDER" "Creating font directory: $USER_FONT_DIR"
    mkdir -p "$USER_FONT_DIR" || die "Failed to create directory: $USER_FONT_DIR"
fi

# === SETUP TEMP ENVIRONMENT ===
# Create a temporary directory for safe downloading and extraction
TEMP_DIR=$(mktemp -d) || die "Failed to create temporary directory"

# Cleanup function to run on EXIT or SIGINT
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Register the trap
trap cleanup EXIT
# Handle user interruption specifically
trap 'echo; warn "Interrupted by user. Exiting..."; cleanup; exit 130' INT

# === MAIN LOGIC ===

# 1. Download
log "$ICON_DOWNLOAD" "Downloading font archive..."
if wget -q -O "$TEMP_DIR/$TAR_FILENAME" "$DOWNLOAD_URL"; then
    info "$ICON_SUCCESS" "Download complete"
else
    die "Download failed from: $DOWNLOAD_URL"
fi

# 2. Extract
log "$ICON_INSTALL" "Extracting files..."
if ! tar zxf "$TEMP_DIR/$TAR_FILENAME" -C "$TEMP_DIR"; then
    die "Failed to extract archive"
fi

# 3. Install
# Locate the specific folder created by tar (handling potential folder name variations safely)
EXTRACTED_DIR="$TEMP_DIR/TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}"
SOURCE_FONT="$EXTRACTED_DIR/TwitterColorEmoji-SVGinOT.ttf"

if [ ! -f "$SOURCE_FONT" ]; then
    # Fallback search if the folder structure isn't exactly as expected
    SOURCE_FONT=$(find "$TEMP_DIR" -name "TwitterColorEmoji-SVGinOT.ttf" | head -n 1)
fi

if [ -n "${SOURCE_FONT:-}" ] && [ -f "$SOURCE_FONT" ]; then
    log "$ICON_FONT" "Installing font file..."
    cp "$SOURCE_FONT" "$TARGET_FONT_FILE" || die "Failed to copy font file to target"
else
    die "Could not locate font file inside the downloaded archive"
fi

# 4. Refresh Cache
log "🔄" "Refreshing font cache..."
if fc-cache -f -v > /dev/null 2>&1; then
    info "$ICON_SUCCESS" "Font cache refreshed"
else
    warn "fc-cache returned an error, you may need to run it manually"
fi

# === FOOTER ===
success "$ICON_SUCCESS" "Twitter Color Emoji Font installation complete!"
