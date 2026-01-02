#!/bin/bash
#==============================================================================
# DESCRIPTION: User-space configuration script. Sets up SSH keys, clones
#              dotfiles, runs GNU Stow, and executes modular user-app scripts.
#
# USAGE:       ./install-step-2-as-user.sh
#
# REQUIREMENTS:
#   - Must NOT be run as root
#   - git, stow, ssh-agent, ssh-keygen must be installed
#   - Internet connection required
#
# NOTES:
#   - Backs up existing .bashrc/.bash_profile before stowing
#   - Interactively prompts for SSH key generation
#   - Pauses for manual web-based configuration steps
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
BASE_DIR="${HOME}/GitHub"                                      # Base directory for repositories
DOTFILES_DIR="${BASE_DIR}/dotfiles"                            # Dotfiles repository location
REPO_URL="git@github.com:usernotnull/dotfiles.git"             # GitHub repository URL
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"                         # SSH key file path
BACKUP_DIR="${HOME}/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"   # Backup directory for existing configs

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="${SCRIPT_DIR}/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "❌ Error: .bash_utils not found at $UTILS_PATH"
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

# Cleanup function for SSH agent
cleanup_ssh_agent() {
    if [ -n "${SSH_AGENT_PID:-}" ]; then
        log "$ICON_CLEAN" "Cleaning up SSH agent (PID: $SSH_AGENT_PID)..."
        kill "$SSH_AGENT_PID" 2>/dev/null || true
    fi
}

# Trap Ctrl+C and script exit
trap 'echo; warn "Interrupted by user. Exiting..."; cleanup_ssh_agent; exit 130' INT
trap cleanup_ssh_agent EXIT

# === HEADER ===
hr
log "$ICON_START" "Starting User Configuration"
info "$ICON_USER" "User: $USER"
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

# Get USER_MODULES_DIR portably (readlink -f not available on macOS)
if command -v realpath >/dev/null 2>&1; then
    SCRIPT_PATH=$(realpath "$0")
else
    SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
fi
USER_MODULES_DIR="$(dirname "$SCRIPT_PATH")/user-apps"

# === MAIN LOGIC ===

# --- 0. Ask User About SSH/Dotfiles Setup ---
echo
read -r -p "Set up SSH keys and dotfiles? [Y/n]: " SETUP_SSH_DOTFILES
SETUP_SSH_DOTFILES="${SETUP_SSH_DOTFILES:-Y}"  # Default to Yes
echo

if [[ ! "$SETUP_SSH_DOTFILES" =~ ^[Yy]$ ]]; then
    info "$ICON_CLOUD" "SSH and dotfiles setup skipped by user"
    info "$ICON_SEARCH" "Proceeding directly to user modules..."
    hr
fi

# --- 1. SSH Agent Setup ---
if [[ "$SETUP_SSH_DOTFILES" =~ ^[Yy]$ ]]; then
    log "$ICON_KEY" "Initializing SSH Agent..."
    # Start the agent and capture the output to evaluate
    if ssh_agent_output=$(ssh-agent -s 2>&1); then
        eval "$ssh_agent_output" >/dev/null
        success "$ICON_SUCCESS" "SSH Agent started (PID: $SSH_AGENT_PID)"

        if [ ! -f "$SSH_KEY_PATH" ]; then
            info "$ICON_SEARCH" "No SSH key found at $SSH_KEY_PATH"

            KEY_EMAIL=""
            while [ -z "${KEY_EMAIL}" ]; do
                read -r -p "Enter email for SSH key (required): " KEY_EMAIL
            done

            log "$ICON_KEY" "Generating new ED25519 SSH key for $KEY_EMAIL..."
            if ssh-keygen -t ed25519 -C "${KEY_EMAIL}" -f "$SSH_KEY_PATH"; then
                success "$ICON_SUCCESS" "SSH key generated successfully"
            else
                die "SSH key generation failed"
            fi

            # Add to agent
            log "$ICON_KEY" "Adding key to SSH agent..."
            if ssh-add "$SSH_KEY_PATH" 2>/dev/null; then
                success "$ICON_SUCCESS" "Key added to SSH agent"
            else
                die "Failed to add key to SSH agent"
            fi

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
            info "$ICON_KEY" "Existing SSH key found at $SSH_KEY_PATH"
            log "$ICON_KEY" "Adding key to SSH agent..."

            # Try to add key, but don't fail if already added or passphrase mismatch
            if ssh-add "$SSH_KEY_PATH" 2>/dev/null; then
                success "$ICON_SUCCESS" "Key added to SSH agent"
            else
                warn "Could not add key (may already be added or passphrase required)"
                info "$ICON_KEY" "Attempting to continue with existing agent keys..."
            fi
        fi
    else
        die "Failed to start ssh-agent: $ssh_agent_output"
    fi
fi

# --- 3. Test SSH Connection ---
if [[ "$SETUP_SSH_DOTFILES" =~ ^[Yy]$ ]]; then
    SSH_CONNECTION_OK=false

    log "$ICON_CLOUD" "Testing GitHub SSH connection..."

    # SSH to GitHub always returns exit code 1, even on success
    # We need to check the output message instead
    if SSH_TEST_OUTPUT=$(ssh -T git@github.com 2>&1) || true; then
        # Check for success message in output
        if echo "$SSH_TEST_OUTPUT" | grep "successfully authenticated" >/dev/null 2>&1; then
            success "$ICON_SUCCESS" "GitHub SSH connection successful!"
            SSH_CONNECTION_OK=true
        else
            warn "GitHub SSH connection failed"
            echo "Output: $SSH_TEST_OUTPUT"
            info "$ICON_SEARCH" "Skipping dotfiles setup, continuing with user modules..."
        fi
    fi

    # --- 4. Dotfiles & Stow ---
    if [ "$SSH_CONNECTION_OK" = true ]; then
        log "$ICON_FOLDER" "Setting up Dotfiles..."

        # Create base directory
        if [ ! -d "$BASE_DIR" ]; then
            mkdir -p "$BASE_DIR" || die "Failed to create directory: $BASE_DIR"
            success "$ICON_FOLDER" "Created directory: $BASE_DIR"
        fi

        if [ -d "$DOTFILES_DIR/.git" ]; then
            info "$ICON_UPDATE" "Updating existing dotfiles repo..."
            if git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null; then
                success "$ICON_SUCCESS" "Dotfiles updated successfully"
            else
                warn "Git pull failed, continuing with current files..."
            fi
        else
            info "$ICON_DOWNLOAD" "Cloning dotfiles repository..."
            if git clone "$REPO_URL" "$DOTFILES_DIR"; then
                success "$ICON_SUCCESS" "Dotfiles cloned successfully"
            else
                warn "Failed to clone dotfiles from $REPO_URL"
                warn "Skipping stow operations..."
            fi
        fi

        if [ -d "$DOTFILES_DIR" ]; then
            # Backup existing config files before stowing
            log "$ICON_CLEAN" "Backing up conflicting config files..."

            backup_needed=false
            for file in .bashrc .bash_profile .bash_logout .profile .zshrc; do
                if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                    if [ "$backup_needed" = false ]; then
                        mkdir -p "$BACKUP_DIR" || die "Failed to create backup directory"
                        backup_needed=true
                    fi

                    if mv "$HOME/$file" "$BACKUP_DIR/"; then
                        info "📦" "Backed up: $file"
                    else
                        warn "Failed to backup: $file"
                    fi
                fi
            done

            if [ "$backup_needed" = true ]; then
                success "$ICON_SUCCESS" "Backups saved to: $BACKUP_DIR"
            else
                info "$ICON_SEARCH" "No conflicting files found to backup"
            fi

            # Run Stow
            log "$ICON_LINK" "Stowing configurations..."

            stow_count=0
            failed_stows=()

            # Use subshell to avoid changing script's working directory
            (
                cd "$DOTFILES_DIR" || die "Failed to enter dotfiles directory"

                # Loop through directories, ignoring hidden ones
                for dir in */; do
                    dirname=$(basename "$dir")

                    # Skip hidden directories
                    if [[ "$dirname" == .* ]]; then
                        continue
                    fi

                    log "$ICON_LINK" "Stowing: $dirname"
                    if stow --restow --target="$HOME" "$dirname" 2>/dev/null; then
                        stow_count=$((stow_count + 1))
                    else
                        warn "Failed to stow: $dirname"
                        failed_stows+=("$dirname")
                    fi
                done

                # Report results in subshell, will be visible in parent
                if [ "$stow_count" -gt 0 ]; then
                    echo  # For clean output
                    success "$ICON_SUCCESS" "Successfully stowed $stow_count configuration(s)"
                fi

                if [ "${#failed_stows[@]}" -gt 0 ]; then
                    warn "Failed to stow: ${failed_stows[*]}"
                fi
            )
        fi
    else
        info "$ICON_SEARCH" "Dotfiles setup skipped due to SSH connection failure"
    fi
fi

# --- 5. Modular User Apps ---
hr
log "📦" "Installing User Modules..."

if [ ! -d "$USER_MODULES_DIR" ]; then
    warn "User modules directory not found: $USER_MODULES_DIR"
    info "$ICON_SEARCH" "Skipping module installation"
else
    # Check if any .sh files exist
    if find "$USER_MODULES_DIR" -maxdepth 1 -name "*.sh" -print -quit 2>/dev/null | grep -q .; then
        module_count=0
        failed_modules=()

        for MODULE_PATH in "$USER_MODULES_DIR"/*.sh; do
            # Skip if glob didn't match any files
            [ -f "$MODULE_PATH" ] || continue

            MODULE_NAME=$(basename "$MODULE_PATH")
            info "🚀" "Executing: $MODULE_NAME"

            if bash "$MODULE_PATH"; then
                success "$ICON_SUCCESS" "Finished: $MODULE_NAME"
                module_count=$((module_count + 1))
            else
                warn "Module failed: $MODULE_NAME"
                failed_modules+=("$MODULE_NAME")
            fi
        done

        if [ "$module_count" -gt 0 ]; then
            success "$ICON_SUCCESS" "Completed $module_count module(s)"
        fi

        if [ "${#failed_modules[@]}" -gt 0 ]; then
            warn "Failed modules: ${failed_modules[*]}"
        fi
    else
        info "$ICON_SEARCH" "No .sh modules found in $USER_MODULES_DIR"
    fi
fi

# --- 6. Manual Interactive Steps ---
hr
log "$ICON_MANUAL" "Post-Install Manual Configuration"
hr

# WhatsApp
warn "ACTION REQUIRED: WhatsApp Web"
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
echo "      IPv4 DNS    : 94.140.14.15, 94.140.15.16"
echo "      IPv6 DNS    : 2a10:50c0::bad1:ff, 2a10:50c0::bad2:ff"
echo
echo "      Run         : sudo resolvectl flush-caches"
echo "      Action      : Disconnect and Reconnect Internet"
echo "      Test        : host pagead2.googlesyndication.com"
echo "                    Should return 0.0.0.0"
wait_for_user

# === FOOTER ===
hr
success "$ICON_PARTY" "User Configuration & Apps Finished!"
if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    info "$ICON_FOLDER" "Backup of original configs: $BACKUP_DIR"
fi
hr
