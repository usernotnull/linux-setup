#!/bin/bash
#==============================================================================
# DESCRIPTION: User-space configuration script. Sets up SSH keys, clones
#              dotfiles, runs GNU Stow, and executes modular user-app scripts.
#
# USAGE:       ./user-config.sh
#
# REQUIREMENTS:
#   - Must NOT be run as root
#   - git, stow, ssh-agent, curl/wget must be installed
#   - Internet connection required
#
# NOTES:
#   - Backs up existing .bashrc/.bash_profile before stowing
#   - Interactively prompts for SSH key generation
#   - Pauses for manual web-based configuration steps
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
BASE_DIR="${HOME}/GitHub"
DOTFILES_DIR="${BASE_DIR}/dotfiles"
REPO_URL="git@github.com:usernotnull/dotfiles.git"
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"
USER_MODULES_DIR="$(dirname "$(readlink -f "$0")")/user-apps"
BACKUP_DIR="${HOME}/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
    exit 1
fi

# Function to pause and wait for user confirmation
wait_for_user() {
    echo
    read -r -p "Press [ENTER] to continue..."
    echo
}

# Trap Ctrl+C
trap 'echo; warn "Interrupted by user. Exiting..."; exit 130' INT

# === HEADER ===
hr
log "$ICON_START" "Starting User Configuration"
info "👤" "User: $USER"
info "$ICON_FOLDER" "Dotfiles: $DOTFILES_DIR"
hr
echo

# === VALIDATIONS ===
# Check against running as root
if [ "$EUID" -eq 0 ]; then
    die "This script must be run as a standard user, not as root."
fi

# Ensure dependencies exist
for cmd in git ssh-agent ssh-keygen stow; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Required command not found: $cmd"
    fi
done

# === MAIN LOGIC ===

# --- 1. SSH Agent Setup ---
log "🔑" "Initializing SSH Agent..."
# Start the agent and capture the output to evaluate
if eval "$(ssh-agent -s)" >/dev/null; then
    success "$ICON_SUCCESS" "SSH Agent started (PID: $SSH_AGENT_PID)"
else
    die "Failed to start ssh-agent"
fi

# --- 2. SSH Key Generation/Check ---
if [ ! -f "$SSH_KEY_PATH" ]; then
    info "$ICON_SEARCH" "No SSH key found at $SSH_KEY_PATH"

    KEY_EMAIL=""
    while [ -z "${KEY_EMAIL}" ]; do
        read -r -p "Enter email for SSH key (required): " KEY_EMAIL
    done

    log "🔑" "Generating new ED25519 SSH key for $KEY_EMAIL..."
    ssh-keygen -t ed25519 -C "${KEY_EMAIL}" -f "$SSH_KEY_PATH" || die "SSH key generation failed"

    # Add to agent
    ssh-add "$SSH_KEY_PATH"

    # Display public key for GitHub
    if [ -f "${SSH_KEY_PATH}.pub" ]; then
        hr
        warn "ACTION REQUIRED: GITHUB SETUP"
        echo "1. Copy the public key below:"
        printf "${CYAN}"
        cat "${SSH_KEY_PATH}.pub"
        printf "${NC}\n"
        echo "2. Visit https://github.com/settings/keys"
        echo "3. Click 'New SSH key' -> Paste key -> Save"
        hr
        wait_for_user
    else
        die "Public key file missing unexpectedly."
    fi
else
    info "🔑" "Existing SSH key found. Attempting to add to agent..."
    # Allow this to fail gracefully (e.g. if already added)
    ssh-add "$SSH_KEY_PATH" || warn "Could not add key (passphrase mismatch or already added)."
fi

# --- 3. Test SSH Connection ---
log "☁️" "Testing GitHub SSH connection..."
SSH_TEST_OUTPUT=$(ssh -T git@github.com 2>&1 || true)

# Check specifically for the success message (exit code is 1 even on success for git@github.com)
if echo "$SSH_TEST_OUTPUT" | grep "successfully authenticated" >/dev/null; then
    success "$ICON_SUCCESS" "GitHub SSH connection successful!"
else
    warn "GitHub SSH connection failed."
    echo "Output: $SSH_TEST_OUTPUT"
    die "Cannot proceed with dotfiles clone without SSH access."
fi

# --- 4. Dotfiles & Stow ---
log "$ICON_FOLDER" "Setting up Dotfiles..."

mkdir -p "$BASE_DIR"

if [ -d "$DOTFILES_DIR/.git" ]; then
    info "🔄" "Updating existing dotfiles repo..."
    git -C "$DOTFILES_DIR" pull --ff-only || warn "Git pull failed, continuing with current files..."
else
    info "⬇️" "Cloning dotfiles..."
    git clone "$REPO_URL" "$DOTFILES_DIR" || die "Failed to clone dotfiles"
fi

if [ -d "$DOTFILES_DIR" ]; then
    # Backup existing config files before stowing
    # We identify files that might conflict (common ones)
    log "🧹" "Backing up conflicting config files..."
    mkdir -p "$BACKUP_DIR"

    for file in .bashrc .bash_profile .bash_logout .profile .zshrc; do
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            mv "$HOME/$file" "$BACKUP_DIR/"
            info "📦" "Moved $file to $BACKUP_DIR"
        fi
    done

    # Run Stow
    log "🔗" "Stowing configurations..."
    # We use a subshell to avoid changing the script's working directory permanently
    (
        cd "$DOTFILES_DIR" || die "Failed to enter dotfiles dir"
        # Loop through directories, ignoring hidden ones and specific excludes
        for dir in */; do
            dirname=$(basename "$dir")
            if [[ "$dirname" == .* ]]; then continue; fi

            log "🔗" "Stowing $dirname"
            stow --restow --target="$HOME" "$dirname" || warn "Failed to stow $dirname"
        done
    )

    success "$ICON_SUCCESS" "Dotfiles setup complete."
fi

# --- 5. Modular User Apps ---
hr
log "📦" "Installing User Modules..."

if [ ! -d "$USER_MODULES_DIR" ]; then
    warn "User modules directory not found: $USER_MODULES_DIR"
else
    # Find files safely
    found_modules=$(find "$USER_MODULES_DIR" -maxdepth 1 -name "*.sh" | wc -l)

    if [ "$found_modules" -gt 0 ]; then
        for MODULE_PATH in "$USER_MODULES_DIR"/*.sh; do
            MODULE_NAME=$(basename "$MODULE_PATH")
            info "🚀" "Executing: $MODULE_NAME"

            if bash "$MODULE_PATH"; then
                success "$ICON_SUCCESS" "Finished: $MODULE_NAME"
            else
                warn "Module failed: $MODULE_NAME"
            fi
        done
    else
        info "$ICON_SEARCH" "No .sh modules found in $USER_MODULES_DIR"
    fi
fi

# --- 6. Manual Interactive Steps ---
hr
log "📝" "Post-Install Manual Configuration"
hr

# WhatsApp
warn "ACTION REQUIRED: Whatsapp Web"
echo "URL: https://web.whatsapp.com/"
echo "Task: Install as PWA (Chrome/Brave/Edge)"
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

# DNS
warn "ACTION REQUIRED: AdGuard DNS"
echo "Task: Open Network Settings -> IPv4/IPv6 Method: Automatic (DHCP)"
echo "      IPv4 DNS: 94.140.14.15, 94.140.15.16"
echo "      IPv6 DNS: 2a10:50c0::bad1:ff, 2a10:50c0::bad2:ff"
echo "      Run: sudo resolvectl flush-caches"
echo "      Action: Disconnect and Reconnect Internet"
wait_for_user

# === FOOTER ===
hr
success "🎉" "User Configuration & Apps Finished!"
info "$ICON_FOLDER" "Backup of original configs stored in: $BACKUP_DIR"
hr
