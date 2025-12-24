#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs Micromamba (fast Mamba package manager)
#
# USAGE:       ./install_micromamba.sh
#
# REQUIREMENTS:
#   - curl
#   - bash
#   - Internet connection
#
# NOTES:
#   - Installs binary to ~/.local/bin/micromamba by default
#   - Modifies shell rc files (.bashrc, .zshrc) via the installer
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
INSTALL_URL="https://micro.mamba.pm/install.sh"
MICROMAMBA_BIN="$HOME/.local/bin/micromamba"
TEMP_INSTALLER=""

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_SNAKE="🐍"
ICON_DOWNLOAD="⬇️"

# === CLEANUP ===
cleanup() {
    if [ -n "${TEMP_INSTALLER:-}" ] && [ -f "$TEMP_INSTALLER" ]; then
        rm -f "$TEMP_INSTALLER"
    fi
}
trap cleanup EXIT
trap 'echo; warn "Interrupted by user. Exiting…"; exit 130' INT

# === HEADER ===
hr
log "$ICON_START" "Micromamba Installer"
info "$ICON_SNAKE" "Target Location: $MICROMAMBA_BIN"
hr
echo

# === VALIDATIONS ===
command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
command -v bash >/dev/null 2>&1 || die "bash is required but not installed."

# === MAIN LOGIC ===

# 1. Check if Micromamba is already installed
if [ -f "$MICROMAMBA_BIN" ]; then
    success "$ICON_SUCCESS" "Micromamba is already installed at $MICROMAMBA_BIN"
    exit 0
fi

# 2. User Prompt
info "$ICON_SNAKE" "Micromamba is an optional fast package manager."
read -r -p "Do you want to install Micromamba? [y/N]: " CONFIRM
CONFIRM="${CONFIRM:-n}" # Default to No

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log "$ICON_CLEAN" "Skipping Micromamba installation as requested."
    exit 0
fi

# 3. Download and Install
log "$ICON_DOWNLOAD" "Downloading installer..."

# Security: Use mktemp for the download to ensure a clean file handle
TEMP_INSTALLER=$(mktemp) || die "Failed to create temporary file"

if ! curl -sL "$INSTALL_URL" -o "$TEMP_INSTALLER"; then
    die "Failed to download installation script."
fi

log "$ICON_START" "Executing installation script..."

# Execute the installer
# We explicitly use bash to run the installer script
if bash "$TEMP_INSTALLER"; then
    echo # Spacer

    # Verify the binary exists after install
    if [ -f "$MICROMAMBA_BIN" ]; then
        success "$ICON_SUCCESS" "Micromamba installation complete."
        info "ℹ️" "You may need to restart your shell for changes to take effect."
    else
        die "Installer finished, but binary not found at $MICROMAMBA_BIN"
    fi
else
    die "Micromamba installation failed."
fi

# === FOOTER ===
success "$ICON_SUCCESS" "Setup finished successfully."
