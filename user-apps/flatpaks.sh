#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs required Flatpak applications with idempotency.
#              Checks for existing installs before attempting installation.
#
# USAGE:       ./install-flatpaks.sh
#
# REQUIREMENTS:
#   - flatpak command must be available
#   - Internet connection
#
# NOTES:
#   - Installs applications in USER scope (--user)
#   - Adds Flathub remote if missing
#   - Uses batch installation for better dependency resolution and speed
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
# List of Flatpak Application IDs to install
APP_IDS=(
    # --- Development ---
    # "com.getpostman.Postman"
    # "io.dbeaver.DBeaverCommunity"
    # "org.gnome.meld"

    # --- Graphics & Design ---
    "it.mijorus.smile"
    # "org.gimp.GIMP"
    "org.kde.digikam"
    # "org.kde.krita"
    "io.freetubeapp.FreeTube"

    # --- Internet & Communication ---
    "eu.betterbird.Betterbird"
    "org.qbittorrent.qBittorrent"

    # --- Media & Audio ---
    "fr.handbrake.ghb"
    # "com.obsproject.Studio"
    # "org.audacityteam.Audacity"
    "org.kde.haruna"
    "org.gnome.Rhythmbox3"

    # --- Music Practice & Performance ---
    "io.github.gillesdegottex.FMIT"
    "io.github.tobagin.tempo"
    "org.rncbc.qpwgraph"

    # --- Productivity & Office ---
    "dev.heppen.webapps"
    # "io.github.alainm23.planify"
    "md.obsidian.Obsidian"
    # "org.freeplane.App"
    "org.kde.kclock"
    "com.super_productivity.SuperProductivity"

    # --- Security ---
    "com.bitwarden.desktop"
    "org.cryptomator.Cryptomator"

    # --- System ---
    "com.github.tchx84.Flatseal"
    "dev.edfloreshz.CosmicTweaks"
    "io.github.plrigaux.sysd-manager"
    "io.missioncenter.MissionCenter"
    "it.mijorus.gearlever"

    # --- Utilities ---
    "com.belmoussaoui.Decoder"
    "com.github.dynobo.normcap"
    "io.github.seadve.Kooha"
    "org.gnome.Calculator"
)

REMOTE_NAME="flathub"
REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

ICON_FLATPAK="📦"

# === HEADER ===
hr
log "$ICON_START" "Starting Flatpak Application Installer"
info "$ICON_FLATPAK" "Target applications: ${#APP_IDS[@]}"
hr
echo

# === VALIDATIONS ===
command -v flatpak >/dev/null 2>&1 || die "Flatpak is not installed. Please install flatpak first."

# === MAIN LOGIC ===

# 1. Configure Remote
# -----------------------------------------------------------------------------
log "$ICON_FLATPAK" "Checking remote configuration..."

# We use || true here because checks inside 'set -e' scripts can trigger exits
if ! flatpak remote-list --user | grep -q "$REMOTE_NAME" 2>/dev/null; then
    info "$ICON_FLATPAK" "Adding $REMOTE_NAME remote..."
    if flatpak remote-add --user --if-not-exists "$REMOTE_NAME" "$REMOTE_URL"; then
        success "$ICON_SUCCESS" "Remote added successfully"
    else
        die "Failed to add remote: $REMOTE_NAME"
    fi
else
    success "$ICON_SUCCESS" "Remote '$REMOTE_NAME' already exists"
fi

echo

# 2. Check Existing Installations
# -----------------------------------------------------------------------------
log "$ICON_SEARCH" "Checking installed applications..."

to_install=()
count=0
total=${#APP_IDS[@]}

# Trap SIGINT for the checking loop
trap 'echo; warn "Interrupted by user during check. Exiting..."; exit 130' INT

for app_id in "${APP_IDS[@]}"; do
    count=$((count + 1))

    # Using printf for a cleaner update line (safe in batch scripts)
    # \033[K clears the line to the right
    printf "\r   Checking %d/%d: %s\033[K" "$count" "$total" "$app_id"

    # Check if installed (returns 0 if found, non-zero if not)
    # Redirect output to void to keep console clean
    if ! flatpak info "$app_id" >/dev/null 2>&1; then
        to_install+=("$app_id")
    fi
done
echo # Newline after the progress indicator

# 3. Batch Installation
# -----------------------------------------------------------------------------
# Batching is preferred for performance (deduplicates shared runtimes)
num_to_install=${#to_install[@]}

if [ "$num_to_install" -eq 0 ]; then
    echo
    success "$ICON_SUCCESS" "All applications are already installed!"
else
    echo
    info "$ICON_FLATPAK" "Found $num_to_install application(s) to install."

    # List them for the user
    for app in "${to_install[@]}"; do
        echo "   • $app"
    done
    echo

    log "$ICON_START" "Starting batch installation..."

    # Trap SIGINT during installation
    trap 'echo; warn "Interrupted by user during installation. Exiting..."; exit 130' INT

    # We execute the install command with the array expanded
    if flatpak install --user -y "$REMOTE_NAME" "${to_install[@]}"; then
        echo
        success "$ICON_SUCCESS" "Successfully installed $num_to_install application(s)"
    else
        echo
        die "Batch installation failed. Check internet connection or disk space."
    fi
fi

# === FOOTER ===
hr
success "$ICON_SUCCESS" "Flatpak setup complete"
