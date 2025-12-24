#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Installs Starship cross-shell prompt
#
# USAGE:       sudo ./install-starship.sh
#
# REQUIREMENTS:
#   - Must be run as root
#   - curl must be available
#   - Internet connection required
#
# NOTES:
#   - Installs to /usr/local/bin by default
#   - Skips installation if Starship is already present
#   - Uses official installation script from starship.rs
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
STARSHIP_INSTALL_URL="https://starship.rs/install.sh"  # Official installation script URL
INSTALL_DIR="/usr/local/bin"                            # Installation directory

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_PROMPT="⭐"  # Starship-specific icon

# === HEADER ===
hr
log "$ICON_START" "Starting Starship Installation"
info "$ICON_PROMPT" "Install directory: $INSTALL_DIR"
hr
echo

# === VALIDATIONS ===
# Check if running as root
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root. Use: sudo $0"
fi

# Check for curl
command -v curl >/dev/null 2>&1 || die "curl is not installed. Please install curl first."

# Check internet connectivity
if ! curl -s --head --connect-timeout 5 "$STARSHIP_INSTALL_URL" > /dev/null; then
    die "Cannot reach $STARSHIP_INSTALL_URL - check your internet connection"
fi

# === MAIN LOGIC ===
# Check if Starship is already installed
if command -v starship >/dev/null 2>&1; then
    current_version=$(starship --version | head -n1)
    success "$ICON_SUCCESS" "Starship is already installed: $current_version"
    info "$ICON_PROMPT" "To upgrade, run: curl -sS $STARSHIP_INSTALL_URL | sh"
    exit 0
fi

# Download and install Starship
log "$ICON_PROMPT" "Downloading Starship installation script..."

if curl -sS "$STARSHIP_INSTALL_URL" | sh -s -- -y; then
    # Verify installation
    if command -v starship >/dev/null 2>&1; then
        installed_version=$(starship --version | head -n1)
        success "$ICON_SUCCESS" "Starship installed successfully: $installed_version"
        info "$ICON_PROMPT" "Installed to: $(command -v starship)"
    else
        die "Installation completed but starship command not found in PATH"
    fi
else
    die "Starship installation script failed"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Starship installation complete"
info "$ICON_PROMPT" "Next steps:"
echo "  1. Add to your shell config (~/.bashrc, ~/.zshrc, etc.):"
echo "     eval \"\$(starship init bash)\"  # For Bash"
echo "     eval \"\$(starship init zsh)\"   # For Zsh"
echo "  2. Restart your shell or run: source ~/.bashrc"
echo "  3. Configure: mkdir -p ~/.config && starship config"
hr
