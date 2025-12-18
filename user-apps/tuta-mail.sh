#!/usr/bin/env bash
# Runs as non-root user. Installs Tuta Mail (Tutanota) AppImage.

set -euo pipefail

# --- TUTA MAIL INSTALLATION ---
APP_NAME="tutanota-desktop-linux.AppImage"
INSTALL_DIR="$HOME/opt"
APP_PATH="$INSTALL_DIR/$APP_NAME"
DOWNLOAD_URL="https://app.tuta.com/desktop/tutanota-desktop-linux.AppImage"

echo "Installing Tuta Mail (AppImage)..."

# Ensure installation directory exists
mkdir -p "$INSTALL_DIR"

# 1. Download/Check AppImage
if [ -f "$APP_PATH" ]; then
    echo "✅ Tuta Mail AppImage already exists at $APP_PATH. Skipping download."
    exit 0
fi

echo "Downloading Tuta Mail from $DOWNLOAD_URL..."
wget -qO "$APP_PATH" "$DOWNLOAD_URL"

if [ -f "$APP_PATH" ]; then
    echo "Making AppImage executable..."
    chmod u+x "$APP_PATH"
    echo "✅ Tuta Mail installed successfully to $APP_PATH"
else
    echo "❌ Error: Download failed."
    exit 1
fi
