#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs hblock, a shell script that blocks ads, tracking, and
#              malware domains by modifying the /etc/hosts file
#
# USAGE:       ./install-hblock.sh
#
# REQUIREMENTS:
#   - curl must be available for downloading files
#   - tar must be available for extracting archive
#   - shasum must be available for checksum verification
#   - sudo/root privileges for installation and execution
#   - Internet connection to download from GitHub
#
# NOTES:
#   - Downloads latest hblock version from official repository
#   - Verifies SHA256 checksum before installation
#   - Installs to /usr/local/bin/hblock
#   - Automatically runs hblock after installation to apply settings
#   - Running hblock modifies /etc/hosts file
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
HBLOCK_REPO="hectorm/hblock"             # GitHub repository
INSTALL_PATH="/usr/local/bin/hblock"     # Installation location
TEMP_DIR=$(mktemp -d /tmp/hblock.XXXXXX) # Temporary download directory

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
ICON_SHIELD="🛡️"
ICON_CHECK="✓"
ICON_PACKAGE="📦"

# === HEADER ===
hr
log "$ICON_START" "Starting hblock installer"
info "$ICON_SHIELD" "Purpose: Ad, tracking, and malware domain blocker"
hr
echo

# === VALIDATIONS ===
# Check for required commands
command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
command -v tar >/dev/null 2>&1 || die "tar is required but not installed"
command -v shasum >/dev/null 2>&1 || die "shasum is required but not installed"

# Check for sufficient privileges
if [ "$EUID" -ne 0 ]; then
    warn "This script requires root privileges for installation"
    die "Please run with sudo: sudo $0"
fi

# Ensure cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

# === MAIN LOGIC ===

# Fetch latest release tag
log "$ICON_SEARCH" "Checking latest hblock release..."
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${HBLOCK_REPO}/releases/latest" 2>/dev/null |
    grep '"tag_name":' | cut -d '"' -f 4 || echo "")

if [ -z "$LATEST_TAG" ]; then
    die "Could not determine latest hblock release tag. Check internet connection."
fi

info "$ICON_VERSION" "Latest available version: $LATEST_TAG"

# Check if already installed
if [ -f "$INSTALL_PATH" ]; then
    INSTALLED_VERSION=$("$INSTALL_PATH" --version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "unknown")
    info "$ICON_CHECK" "hblock is already installed (version: $INSTALLED_VERSION)"

    read -r -p "Reinstall hblock ${LATEST_TAG}? [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "$ICON_SUCCESS" "Installation skipped"
        exit 0
    fi
    echo
fi

# Download tarball
TARBALL_URL="https://github.com/${HBLOCK_REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"
TARBALL_PATH="$TEMP_DIR/hblock.tar.gz"

log "$ICON_DOWNLOAD" "Downloading hblock ${LATEST_TAG} archive..."
if ! curl -fsSL -o "$TARBALL_PATH" "$TARBALL_URL"; then
    die "Failed to download hblock archive from $TARBALL_URL"
fi

if [ ! -s "$TARBALL_PATH" ]; then
    die "Downloaded file is empty: $TARBALL_PATH"
fi

# Extract tarball
log "$ICON_PACKAGE" "Extracting archive..."
if ! tar -xzf "$TARBALL_PATH" -C "$TEMP_DIR"; then
    die "Failed to extract tarball"
fi

# Find extracted directory (should be hblock-<version> without 'v' prefix)
EXTRACTED_DIR="$TEMP_DIR/hblock-${LATEST_TAG#v}"

if [ ! -d "$EXTRACTED_DIR" ]; then
    die "Extracted directory not found: $EXTRACTED_DIR"
fi

# Verify files exist
HBLOCK_FILE="$EXTRACTED_DIR/hblock"
CHECKSUM_FILE="$EXTRACTED_DIR/hblock.sha256"

if [ ! -f "$HBLOCK_FILE" ]; then
    die "hblock script not found in extracted archive"
fi

if [ ! -f "$CHECKSUM_FILE" ]; then
    warn "hblock.sha256 not found in extracted archive, skipping checksum verification"
    SKIP_CHECKSUM=true
else
    SKIP_CHECKSUM=false
fi

# Verify checksum
if [ "$SKIP_CHECKSUM" = false ]; then
    log "$ICON_SEARCH" "Verifying SHA256 checksum..."
    EXPECTED_CHECKSUM=$(cat "$CHECKSUM_FILE" | awk '{print $1}')

    if echo "$EXPECTED_CHECKSUM  $HBLOCK_FILE" | shasum -c >/dev/null 2>&1; then
        success "$ICON_CHECK" "Checksum verification passed"
    else
        die "Checksum verification failed! File may be corrupted or tampered with"
    fi
fi

# Install hblock
log "$ICON_PACKAGE" "Installing hblock to $INSTALL_PATH..."
if ! cp "$HBLOCK_FILE" "$INSTALL_PATH"; then
    die "Failed to copy hblock to $INSTALL_PATH"
fi

# Set ownership and permissions
chown 0:0 "$INSTALL_PATH" || warn "Failed to set ownership"
chmod 755 "$INSTALL_PATH" || warn "Failed to set permissions"

success "$ICON_SUCCESS" "hblock installed successfully"

# Verify installation
if command -v hblock >/dev/null 2>&1; then
    INSTALLED_VERSION=$(hblock --version 2>/dev/null | head -n 1 | awk '{print $2}')
    info "$ICON_VERSION" "Installed version: $INSTALLED_VERSION"
else
    die "Installation completed but 'hblock' command not found in PATH"
fi

# === APPLY SETTINGS ===info "♻️" "To disable blocking: hblock -S none -D none"

echo
hr
log "$ICON_SHIELD" "Applying hblock settings (this will modify /etc/hosts)..."
echo

if hblock; then
    success "$ICON_SUCCESS" "hblock settings applied successfully"
else
    warn "hblock execution encountered issues"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "hblock installation and setup complete"
info "💡" "Usage: hblock [options]"
info "🔄" "To update blocklist: hblock"
info "♻️" "To disable blocking: hblock -S none -D none"
info "📚" "Documentation: https://github.com/hectorm/hblock"
hr
