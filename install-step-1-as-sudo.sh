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
INTERACTIVE_MODE=true           # Set to false to skip end-of-script prompts

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

# 1. Update Package Lists
info "🔄" "Updating APT package lists..."
if apt update -qq; then
    success "$ICON_SUCCESS" "Package lists updated."
else
    warn "APT update returned a non-zero exit code. Proceeding, but errors may occur."
fi
echo

# 2. Execute Modules
log "$ICON_START" "Starting modular installation..."

# Use process substitution to avoid subshell variable scope issues
# find -print0 | sort -z handles filenames with spaces/newlines correctly
while IFS= read -r -d '' module; do
    module_name=$(basename "$module")

    hr
    info "▶️" "Executing module: $module_name"

    # Execute the module script in a new bash process
    # Passing the environment ensures variables/functions don't bleed unexpectedly
    if bash "$module"; then
        success "$ICON_SUCCESS" "Module $module_name completed successfully."
    else
        die "Module $module_name failed. Aborting installation."
    fi

done < <(find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

echo
success "$ICON_SUCCESS" "All automated modules finished!"

# 3. Post-Install Interactive Configurations
if [ "$INTERACTIVE_MODE" = true ]; then
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

    # Espanso Configuration
    warn "ACTION REQUIRED: Espanso"
    echo "Run the following command in another terminal:"
    printf "${CYAN}>>> espanso service register && espanso start${NC}\n"
    read -r -p "Press [ENTER] when done..." _
    echo

    success "$ICON_SUCCESS" "Interactive configuration steps completed."
fi

# === FOOTER ===
hr
success "$ICON_SUCCESS" "System setup complete."
hr
