#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs MuseScore Studio (AppImage)
#
# USAGE:       ./install-musescore.sh
#
# REQUIREMENTS:
#   - curl or wget for downloading
#   - Internet connection
#
# NOTES:
#   - Automatically detects system architecture (x86_64, aarch64)
#   - Skips installation if AppImage already exists
#   - Downloads AppImage to ~/.local/bin/
#   - Only x86_64 architecture is officially supported by MuseScore
#   - Use Gear Lever for desktop integration
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
GITHUB_REPO="musescore/MuseScore"                   # GitHub repository
INSTALL_DIR="$HOME/Applications"                    # Where to install the AppImage
APP_NAME="MuseScore-Studio"                         # Base name for the AppImage
SEARCH_PATTERN="musescore_studio"                   # Pattern to detect existing installation

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

ICON_DOWNLOAD="⬇️"
ICON_CHECK="🔍"
ICON_PACKAGE="📦"
ICON_VERSION="🏷️"
ICON_SKIP="⏭️"
ICON_MUSIC="🎵"

# === HEADER ===
hr
log "$ICON_START" "MuseScore Studio Installer"
info "$ICON_PACKAGE" "Repository: $GITHUB_REPO"
hr
echo

# === VALIDATIONS ===

# Check for required commands
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    die "Neither curl nor wget found. Please install one of them."
fi

# Detect architecture
ARCH=$(uname -m)

if [ "$ARCH" != "x86_64" ]; then
    warn "MuseScore Studio officially supports only x86_64 architecture"
    info "💡" "Your system is: $ARCH"
    read -r -p "Continue anyway? [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        die "Installation cancelled"
    fi
fi

# === CHECK IF ALREADY INSTALLED ===

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Search for any file matching the pattern (case-insensitive)
if find "$INSTALL_DIR" -maxdepth 1 -type f -iname "*${SEARCH_PATTERN}*.appimage" -print -quit | grep -q .; then
    EXISTING_FILE=$(find "$INSTALL_DIR" -maxdepth 1 -type f -iname "*${SEARCH_PATTERN}*.appimage" -print -quit)
    success "$ICON_SKIP" "MuseScore Studio is already installed"
    info "$ICON_MUSIC" "Location: $EXISTING_FILE"
    echo
    hr
    exit 0
fi

log "$ICON_PACKAGE" "No existing installation found, proceeding with download..."
echo

# === FETCH LATEST RELEASE ===
log "$ICON_DOWNLOAD" "Fetching latest release information from GitHub..."

# Use curl or wget to get latest release info
if command -v curl >/dev/null 2>&1; then
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest")
else
    RELEASE_JSON=$(wget -q --show-progress -O- "https://api.github.com/repos/$GITHUB_REPO/releases/latest")
fi

# Extract version tag
if [[ "$RELEASE_JSON" =~ \"tag_name\":[[:space:]]*\"([^\"]+)\" ]]; then
    LATEST_VERSION="${BASH_REMATCH[1]}"
else
    die "Could not parse latest version from GitHub API"
fi

# Find AppImage download URL for x86_64
DOWNLOAD_URL=""
while IFS= read -r line; do
    if [[ "$line" =~ \"browser_download_url\":[[:space:]]*\"([^\"]+x86_64\.AppImage)\" ]]; then
        DOWNLOAD_URL="${BASH_REMATCH[1]}"
        break
    fi
done <<< "$RELEASE_JSON"

if [ -z "$DOWNLOAD_URL" ]; then
    die "Could not find AppImage download URL for x86_64 architecture"
fi

success "$ICON_VERSION" "Latest version available: $LATEST_VERSION"
echo

# === DOWNLOAD ===
log "$ICON_DOWNLOAD" "Downloading MuseScore Studio $LATEST_VERSION..."

# Target filename
APPIMAGE_FILE="$INSTALL_DIR/$APP_NAME.AppImage"

# Download the file
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o "$APPIMAGE_FILE" "$DOWNLOAD_URL"; then
        success "$ICON_DOWNLOAD" "Downloaded AppImage"
    else
        die "Failed to download AppImage"
    fi
else
    if wget -q --show-progress -O "$APPIMAGE_FILE" "$DOWNLOAD_URL"; then
        success "$ICON_DOWNLOAD" "Downloaded AppImage"
    else
        die "Failed to download AppImage"
    fi
fi

# Make executable
chmod +x "$APPIMAGE_FILE"
success "$ICON_PACKAGE" "Made AppImage executable"
echo

# === FOOTER ===
hr
success "$ICON_SUCCESS" "MuseScore Studio installation complete!"
info "$ICON_MUSIC" "Installed to: $APPIMAGE_FILE"
info "💡" "Use Gear Lever to integrate with your desktop environment"
hr
