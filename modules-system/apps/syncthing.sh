#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Syncthing via its official Debian repository
#
# USAGE:       sudo ./install-syncthing.sh
#
# REQUIREMENTS:
#   - Root/sudo privileges
#   - Debian-based system (Ubuntu, Debian, etc.)
#   - curl must be available
#   - Internet connection for package downloads
#
# NOTES:
#   - Adds Syncthing's official stable-v2 repository
#   - Skips installation if already installed
#   - Safe to run multiple times (idempotent)
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
APP_PACKAGE="syncthing"                                      # Package name to install
REPO_FILE="/etc/apt/sources.list.d/syncthing.list"         # APT repository list file
KEYRING_PATH="/etc/apt/keyrings/syncthing-archive-keyring.gpg"  # GPG keyring location
REPO_URL="https://apt.syncthing.net/"                       # Repository URL
KEYRING_URL="https://syncthing.net/release-key.gpg"        # GPG key URL

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
ICON_KEY="🔑"
ICON_UPDATE="🔄"

# === HEADER ===
hr
log "$ICON_START" "Syncthing Installer"
info "$ICON_PACKAGE" "Package: $APP_PACKAGE"
info "$ICON_FOLDER" "Repository: $REPO_URL"
hr
echo

# === VALIDATIONS ===
# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

# Check for required commands
command -v curl >/dev/null 2>&1 || die "curl command not found. Install it with: apt install curl"
command -v apt >/dev/null 2>&1 || die "apt command not found. This script requires a Debian-based system"

# === MAIN LOGIC ===

# Check if package is already installed
if dpkg -l | grep "^ii.*${APP_PACKAGE}" > /dev/null 2>&1; then
    success "$ICON_SUCCESS" "Syncthing is already installed. Skipping installation."
    exit 0
fi

# Add the release PGP keys and repository sources
if [ ! -f "${REPO_FILE}" ]; then
    log "$ICON_KEY" "Adding Syncthing PGP key..."

    # Create keyrings directory if it doesn't exist
    mkdir -p /etc/apt/keyrings

    # Download GPG key
    if curl -fsSL -o "$KEYRING_PATH" "$KEYRING_URL"; then
        success "$ICON_KEY" "GPG key downloaded successfully"
    else
        die "Failed to download Syncthing GPG key from $KEYRING_URL"
    fi

    log "$ICON_FOLDER" "Adding Syncthing stable-v2 repository..."
    if echo "deb [signed-by=$KEYRING_PATH] $REPO_URL syncthing stable-v2" > "${REPO_FILE}"; then
        success "$ICON_FOLDER" "Repository configuration added"
    else
        die "Failed to create repository configuration file"
    fi
else
    info "$ICON_FOLDER" "Syncthing repository already configured"
fi

# Update package lists and install syncthing
log "$ICON_UPDATE" "Updating package lists..."
if apt update -qq; then
    success "$ICON_UPDATE" "Package lists updated"
else
    die "Failed to update package lists"
fi

log "$ICON_PACKAGE" "Installing $APP_PACKAGE..."
if apt install -y "${APP_PACKAGE}"; then
    success "$ICON_PACKAGE" "Package installed successfully"
else
    die "Failed to install $APP_PACKAGE"
fi

# Verify installation
if command -v syncthing >/dev/null 2>&1; then
    version=$(syncthing --version | head -n1 || echo "unknown")
    success "$ICON_SUCCESS" "Syncthing installed successfully: $version"
else
    warn "Syncthing package installed but command not found in PATH"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Syncthing installation complete!"
info "💡" "Next steps:"
info "   " "- Run 'syncthing' to start the service"
info "   " "- Access web GUI at http://localhost:8384"
info "   " "- Consider enabling as a systemd service"
hr
