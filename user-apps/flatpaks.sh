#!/bin/bash
#==============================================================================
# DESCRIPTION: Installs required Flatpak applications with idempotency.
#              Checks for existing installs before attempting installation.
#
# USAGE:       ./flatpaks.sh
#
# REQUIREMENTS:
#   - flatpak command must be available
#   - Internet connection
#   - $HOME/.bash_utils helper functions file
#
# NOTES:
#   - Installs applications in USER scope (--user)
#   - Adds Flathub remote if missing
#   - Uses batch installation for better dependency resolution and speed
#   - Press Ctrl+C to cancel at any time
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
# List of Flatpak Application IDs to install (default)
APP_IDS=(
    # --- Graphics & Design ---
    "it.mijorus.smile"        # Emoji picker
    "io.freetubeapp.FreeTube" # YouTube client

    # --- Internet & Communication ---
    "eu.betterbird.Betterbird"    # Email client
    "org.qbittorrent.qBittorrent" # Torrent client

    # --- Media & Audio ---
    "fr.handbrake.ghb"     # Video transcoder
    "org.kde.haruna"       # Video player
    "org.gnome.Rhythmbox3" # Music player

    # --- Productivity & Office ---
    "dev.heppen.webapps"                       # Web app manager
    "md.obsidian.Obsidian"                     # Note-taking app
    "org.kde.kclock"                           # Clock and timer
    "com.super_productivity.SuperProductivity" # Task manager

    # --- Security ---
    "com.bitwarden.desktop"       # Password manager
    "org.cryptomator.Cryptomator" # File encryption

    # --- System ---
    "com.github.tchx84.Flatseal"      # Flatpak permissions manager
    "dev.edfloreshz.CosmicTweaks"     # COSMIC desktop tweaks
    "io.github.plrigaux.sysd-manager" # Systemd manager
    "io.missioncenter.MissionCenter"  # System monitor
    "it.mijorus.gearlever"            # AppImage manager

    # --- Utilities ---
    "com.belmoussaoui.Decoder"  # QR code scanner
    "com.github.dynobo.normcap" # OCR screen capture
    "io.github.seadve.Kooha"    # Screen recorder
    "org.gnome.Calculator"      # Calculator
    "org.localsend.localsend_app"
)

# Optional Flatpak Application IDs (user will be prompted)
OPTIONAL_APP_IDS=(
    # --- Development ---
    "com.getpostman.Postman"      # API testing tool
    "io.dbeaver.DBeaverCommunity" # Database tool
    "org.gnome.meld"              # File diff tool

    # --- Graphics & Design ---
    "org.gimp.GIMP"   # Image editor
    "org.kde.krita"   # Digital painting
    "org.kde.digikam" # Photo management

    # --- Media & Audio ---
    "com.obsproject.Studio"     # Streaming/recording
    "org.audacityteam.Audacity" # Audio editor

    # --- Music Practice & Performance ---
    "io.github.gillesdegottex.FMIT" # Musical instrument tuner
    "io.github.tobagin.tempo"       # Metronome
    "org.rncbc.qpwgraph"            # PipeWire graph manager

    # --- Productivity & Office ---
    "io.github.alainm23.planify" # Task planner
    "org.freeplane.App"          # Mind mapping
)

REMOTE_NAME="flathub"                                        # Flatpak repository name
REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo" # Repository URL

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

ICON_FLATPAK="📦"

# Prompt user for optional app installation
prompt_optional_app() {
    local app_id="${1:-}"
    local response

    read -r -p "   Install $app_id? [y/N]: " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]]
}

# === HEADER ===
hr
log "$ICON_START" "Starting Flatpak Application Installer"
info "$ICON_FLATPAK" "Default applications: ${#APP_IDS[@]}"
info "$ICON_FLATPAK" "Optional applications: ${#OPTIONAL_APP_IDS[@]}"
hr
echo

# === VALIDATIONS ===
if ! command -v flatpak >/dev/null 2>&1; then
    die "Flatpak is not installed. Please install flatpak first."
fi

# === MAIN LOGIC ===

# 1. Configure Remote
# -----------------------------------------------------------------------------
log "$ICON_FLATPAK" "Checking remote configuration..."

if flatpak remote-list --user | grep "$REMOTE_NAME" >/dev/null 2>&1; then
    success "$ICON_SUCCESS" "Remote '$REMOTE_NAME' already exists"
else
    info "$ICON_FLATPAK" "Adding $REMOTE_NAME remote..."
    if flatpak remote-add --user --if-not-exists "$REMOTE_NAME" "$REMOTE_URL" 2>&1; then
        success "$ICON_SUCCESS" "Remote added successfully"
    else
        die "Failed to add remote: $REMOTE_NAME"
    fi
fi

echo

# 2. Check Existing Installations
# -----------------------------------------------------------------------------
log "$ICON_SEARCH" "Checking installed applications..."

# Read all apps into array for proper stdin handling during prompts
mapfile -t apps_to_check < <(printf '%s\n' "${APP_IDS[@]}")
to_install=()
count=0
total=${#apps_to_check[@]}

# Trap SIGINT for the checking loop
trap 'echo; warn "Interrupted by user during check. Exiting..."; exit 130' INT

for app_id in "${apps_to_check[@]}"; do
    count=$((count + 1))

    # Display progress (clear to end of line)
    printf "\r   Checking %d/%d: %s\033[K" "$count" "$total" "$app_id"

    # Check if installed
    if flatpak info "$app_id" >/dev/null 2>&1; then
        # Already installed, skip
        :
    else
        to_install+=("$app_id")
    fi
done
echo # Newline after progress indicator

# 3. Batch Installation
# -----------------------------------------------------------------------------
num_to_install=${#to_install[@]}

if [ "$num_to_install" -eq 0 ]; then
    echo
    success "$ICON_SUCCESS" "All default applications are already installed!"
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

    if flatpak install --user -y "$REMOTE_NAME" "${to_install[@]}" 2>&1; then
        echo
        success "$ICON_SUCCESS" "Successfully installed $num_to_install application(s)"
    else
        echo
        die "Batch installation failed. Check internet connection or disk space."
    fi
fi

# 4. Optional Applications
# -----------------------------------------------------------------------------
echo
log "$ICON_FLATPAK" "Checking for optional applications..."
echo

# Read optional apps into array for proper stdin handling
mapfile -t optional_apps < <(printf '%s\n' "${OPTIONAL_APP_IDS[@]}")
optional_to_install=()

for app_id in "${optional_apps[@]}"; do
    if prompt_optional_app "$app_id"; then
        optional_to_install+=("$app_id")
    fi
done

if [ ${#optional_to_install[@]} -gt 0 ]; then
    echo
    log "$ICON_START" "Installing optional application(s)..."

    # Trap SIGINT during installation
    trap 'echo; warn "Interrupted by user during optional installation. Exiting..."; exit 130' INT

    if flatpak install --user -y "$REMOTE_NAME" "${optional_to_install[@]}" 2>&1; then
        echo
        success "$ICON_SUCCESS" "Successfully installed ${#optional_to_install[@]} optional application(s)"
    else
        echo
        die "Optional batch installation failed. Check internet connection or disk space."
    fi
else
    echo
    info "$ICON_FLATPAK" "No optional applications selected"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Flatpak setup complete"
hr
