#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Installs ProtonVPN GNOME Desktop client on Debian-based systems
#
# USAGE:       sudo ./install-protonvpn.sh
#
# REQUIREMENTS:
#   - Root/sudo privileges required
#   - Debian-based system (Ubuntu, Debian, etc.)
#   - Internet connectivity
#   - curl, wget, dpkg, apt-get must be available
#
# NOTES:
#   - Automatically fetches the latest stable repository configuration
#   - Installs proton-vpn-gnome-desktop package from official Proton repository
#   - Safe to run multiple times (idempotent)
#   - Press Ctrl+C to cancel during long operations
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="proton-vpn-gnome-desktop"                                    # Package name to install
PROTON_REPO_URL="https://repo.protonvpn.com/debian/dists/stable/main/binary-all"  # Repository URL
TEMP_DIR="/tmp/protonvpn-install-$$"                                      # Unique temp directory for this process

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

# === CLEANUP HANDLER ===
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT
trap 'echo; warn "Installation interrupted by user"; cleanup; exit 130' INT TERM

# === HEADER ===
hr
log "$ICON_START" "ProtonVPN Installation Script"
info "📦" "Target package: $APP_PACKAGE"
hr
echo

# === VALIDATIONS ===
# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root. Try: sudo $0"
fi

# Check for required commands
for cmd in curl wget dpkg apt-get; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Required command not found: $cmd"
    fi
done

# Check internet connectivity
if ! curl -s --max-time 5 https://repo.protonvpn.com >/dev/null 2>&1; then
    die "Cannot reach ProtonVPN repository. Check your internet connection."
fi

# Check if already installed
if dpkg -s "$APP_PACKAGE" 2>/dev/null | grep -q "Status: install ok installed"; then
    success "$ICON_SUCCESS" "ProtonVPN is already installed."
    exit 0
fi

# Create temporary directory
mkdir -p "$TEMP_DIR" || die "Failed to create temporary directory"

# === MAIN LOGIC ===

# Fetch latest repository package name
log "$ICON_SEARCH" "Fetching latest repository configuration..."
TEMP_LIST="$TEMP_DIR/package_list"

curl -s "$PROTON_REPO_URL/" >"$TEMP_LIST" &
CURL_PID=$!
show_spinner "$CURL_PID" "Downloading package list"

LATEST_DEB=$(grep -o 'protonvpn-stable-release_[0-9.]*_all.deb' "$TEMP_LIST" | sort -V | tail -n 1)

if [[ -z "$LATEST_DEB" ]]; then
    die "Could not find latest .deb package on Proton servers."
fi

log "$ICON_SUCCESS" "Found: $LATEST_DEB"

# Download repository configuration package
TEMP_DEB="$TEMP_DIR/$LATEST_DEB"
log "⬇️" "Downloading repository configuration..."

wget -q -O "$TEMP_DEB" "$PROTON_REPO_URL/$LATEST_DEB" &
WGET_PID=$!
show_spinner "$WGET_PID" "Downloading $LATEST_DEB"

if [[ ! -f "$TEMP_DEB" ]]; then
    die "Failed to download repository package"
fi

# Install repository configuration
log "📦" "Installing repository configuration..."
if ! dpkg -i "$TEMP_DEB" >/dev/null 2>&1; then
    warn "Repository package installation had warnings (this is usually normal)"
fi
success "$ICON_SUCCESS" "Repository configured"

# Update package list
log "🔄" "Updating package lists..."
DEBIAN_FRONTEND=noninteractive apt-get update -y -qq &
UPDATE_PID=$!
show_spinner "$UPDATE_PID" "Running apt-get update"

# Install ProtonVPN
log "📦" "Installing $APP_PACKAGE..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "$APP_PACKAGE" >/dev/null 2>&1 &
INSTALL_PID=$!
show_spinner "$INSTALL_PID" "Installing ProtonVPN (this may take a few minutes)"

# === FOOTER ===
echo
success "$ICON_SUCCESS" "ProtonVPN installation complete!"
info "💡" "Launch ProtonVPN from your applications menu or run: protonvpn-app"
hr
