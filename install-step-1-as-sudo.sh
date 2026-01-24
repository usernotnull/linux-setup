#!/bin/bash
#==============================================================================
# DESCRIPTION: Main System Installation Script
#              Executes installation modules sequentially from the modules directory
#              and handles post-installation interactive configuration prompts.
#
# USAGE:       sudo ./install.sh
#
# REQUIREMENTS:
#   - Must be run as root (sudo)
#   - Directory 'modules-system' must exist in the script's location
#   - .bash_utils helper library (optional, falls back to defaults if missing)
#
# NOTES:
#   - Modules are executed in alphanumeric order (01-*, 02-*, etc.)
#   - If any module fails, the entire installation aborts immediately
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules-system"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

# === HEADER ===
hr
log "$ICON_START" "System Modular Installer"
info "$ICON_INFO" "Modules Directory: $MODULES_DIR"
hr
echo

# === VALIDATIONS ===
# Ensure script is run with sudo permissions
if [ "$EUID" -ne 0 ]; then
    die "This script must be run with sudo privileges."
fi

# Ensure modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    die "Modules directory not found at: $MODULES_DIR"
fi

# Trap Ctrl+C for graceful exit
trap 'echo; warn "Installation interrupted by user."; exit 130' INT

# === MAIN LOGIC ===

# Read all module paths into an array first
mapfile -t -d '' modules < <(find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

# Now iterate without stdin redirection conflicts
for module in "${modules[@]}"; do
    module_name=$(basename "$module")

    hr
    info "▶️" "Executing module: $module_name"

    # Execute the module script - stdin is now available for interactive prompts
    if bash "$module"; then
        success "$ICON_SUCCESS" "Module $module_name completed successfully."
    else
        die "Module $module_name failed. Aborting installation."
    fi
done

echo
success "$ICON_SUCCESS" "All automated modules finished!"

# Post-Install Interactive Configurations
echo
hr
log "📦" "Post-install INTERACTIVE configurations"
hr
echo

# Brave Configuration
warn "ACTION REQUIRED: Brave Browser"
echo "1. Open Brave"
echo "2. Go to Settings > Sync"
echo "3. Complete setup"
read -r -p "Press [ENTER] when done..." _
echo

success "$ICON_SUCCESS" "Interactive configuration steps completed."

# === FOOTER ===
hr
success "$ICON_SUCCESS" "System setup complete."
hr
