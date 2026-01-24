set -euo pipefail

# === CONFIGURATION ===
BASE_DIR="${HOME}/GitHub"                                   # Base directory for repositories
DOTFILES_DIR="${BASE_DIR}/dotfiles"                         # Dotfiles repository location
REPO_URL="git@github.com:usernotnull/dotfiles.git"          # GitHub repository URL
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"                      # SSH key file path
BACKUP_DIR="${HOME}/dotfiles_backup_$(date +%Y%m%d_%H%M%S)" # Backup directory for existing configs

# === HELPER FUNCTIONS ===
if [ -f "$HOME/.bash_utils" ]; then
    source "$HOME/.bash_utils"
else
    echo "Error: .bash_utils not found!"
    exit 1
fi

# Additional icons for this script
ICON_KEY="🔑"
ICON_CLOUD="☁️"
ICON_LINK="🔗"
ICON_UPDATE="🔄"
ICON_DOWNLOAD="⬇️"
ICON_PARTY="🎉"
ICON_MANUAL="📋"
ICON_USER="👤"

# Function to pause and wait for user confirmation
wait_for_user() {
    echo
    read -r -p "Press [ENTER] to continue..."
    echo
}

# Trap Ctrl+C and script exit
trap 'echo; warn "Interrupted by user. Exiting..."; cleanup_ssh_agent; exit 130' INT
trap cleanup_ssh_agent EXIT

hr
log "$ICON_MANUAL" "Post-Install Manual Configuration"
hr

# Restore Home
warn "ACTION REQUIRED: Restore Home"
echo "To restore home directory, in another terminal, run: home-restore"
wait_for_user

# SyncThing
warn "ACTION REQUIRED: SyncThing"
echo "URL: http://127.0.0.1:8384/"
echo "Task: 1. Enable ONLY local discovery"
echo "      2. Add devices (tcp://x.x.x.x:22000)"
wait_for_user

# pCloud
warn "ACTION REQUIRED: pCloud"
echo "URL: https://www.pcloud.com/how-to-install-pcloud-drive-linux.html"
echo "Task: Download AppImage -> chmod +x -> Run -> Login"
wait_for_user

# pCloud Links
warn "ACTION REQUIRED: pCloud Symlinks"
echo "RUN: ln -s /home/john/pCloudDrive/Music/ ~/Music/cloud"
wait_for_user

# DNS
warn "ACTION REQUIRED: AdGuard DNS"
echo "Task: Open Network Settings -> IPv4/IPv6 Method: Automatic (DHCP)"
echo "      IPv4 DNS    : 94.140.14.15, 94.140.15.16"
echo "      IPv6 DNS    : 2a10:50c0::bad1:ff, 2a10:50c0::bad2:ff"
echo
echo "      Run         : sudo resolvectl flush-caches"
echo "      Action      : Disconnect and Reconnect Internet"
echo "      Test        : host pagead2.googlesyndication.com"
echo "                    Should return 0.0.0.0"
wait_for_user

# PWA1
warn "ACTION REQUIRED: PWA via Brave"
echo "Run   : Brave"
echo "+---+"
echo "URL       : https://web.whatsapp.com"
echo "+---+"
echo "URL       : https://claude.ai"
echo "+---+"
wait_for_user

# PWA2
warn "ACTION REQUIRED: PWA via Quick Web Apps"
echo "Run   : Quick Web Apps"
echo "+---+"
echo "TITLE     : ChatGPT"
echo "URL       : https://chatgpt.com"
echo "+---+"
echo "TITLE     : Kimi"
echo "URL       : https://www.kimi.com"
echo "+---+"
echo "TITLE     : Gemini"
echo "URL       : https://gemini.google.com"
echo "+---+"
wait_for_user

# Panel Applets
warn "ACTION REQUIRED: SETTING → Panel Applets"
echo "  Start segment →"
echo "      Numbered Workspaces"
echo "      Tiling"
echo "      App Library Button"
echo "      Notifications Tray"
echo
echo "  Center segment →"
echo "      App Tray"
echo
echo "  End segment →"
echo "      Notifications Center"
echo "      Input Sources"
echo "      Sound"
echo "      Bluetooth"
echo "      Network"
echo "      Power & Battery"
echo "      User Session"
echo "      Date, Time & Calendar"
wait_for_user

# Keyboard Shortcuts
warn "ACTION REQUIRED: SETTING → Keyboard Shortcuts"
echo "  Keyboard →"
echo "      State on Boot: ON"
echo "  Acccessibility →"
echo "      Zoom in/out                                 : Remove ,."
echo "  System →"
echo "      Lock the screen                             : Disable"
echo "      Take a Screenshot                           : SUPER+SHIFT+s"
echo
echo "  Custom →"
echo "      flatpak run com.github.dynobo.normcap       : SUPER+SHIFT+d"
echo "      cosmic-term -e btop                         : Ctrl+Alt+Delete"
echo "      flatpak run io.missioncenter.MissionCenter  : Ctrl+Alt+SHIFT+Delete"
echo "      flatpak run eu.betterbird.Betterbird        : Super+e"
echo "      flatpak run flatpak it.mijorus.smile        : Super+."
echo "      systemctl poweroff                          : Super+ESC"
wait_for_user

# Mouse
warn "ACTION REQUIRED: SETTING → Mouse"
echo "  Mouse Speed: 57"
echo "  Enable acceleration"
echo "  Scrolling Speed: 50"
echo "  Natural Scrolling OFF"
wait_for_user

# Touchpad
warn "ACTION REQUIRED: SETTING → Touchpad"
echo "  Touchpad Speed: 80"
echo "  Scroll with 2 fingers"
echo "  Scrolling Speed: 35"
echo "  Natural Scrolling ON"
wait_for_user
