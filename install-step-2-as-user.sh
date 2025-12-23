#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# User Configuration Script
# This MUST be run manually by the target user after the main root install.
#-------------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status or variable is unset.
set -euo pipefail

# Define path variables locally
BASE_DIR="$HOME/GitHub"
DOTFILES_DIR="$HOME/GitHub/dotfiles"
REPO_URL="git@github.com:usernotnull/dotfiles.git"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
USER_MODULES_DIR="$(dirname "$(readlink -f "$0")")/user-apps"

# Define colors for status messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# $EUID is the Effective User ID. Root's ID is 0.
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ This script must be run as a standard user, not as root or with sudo.${NC}"
    exit 1
fi

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🔑 Starting User Configuration: SSH Key Setup and Dotfiles${NC}"
echo -e "${GREEN}========================================================================${NC}"

# 1. Start the ssh-agent immediately (needed for all subsequent ssh/git operations)
echo -e "${GREEN}Starting SSH agent...${NC}"
# Must use eval to set environment variables
eval "$(ssh-agent -s)"

# --- GITHUB SSH KEY SETUP ---
echo 'Checking GitHub SSH Key...'

# Check if the key needs to be generated
if [ ! -f "$SSH_KEY_PATH" ]; then

  # --- NEW KEY GENERATION FLOW (Now fully interactive) ---
  KEY_EMAIL=""
  while [ -z "${KEY_EMAIL}" ]; do
    read -rp "Enter email for SSH key (required): " KEY_EMAIL
  done

  echo "Generating new ED25519 SSH key (${KEY_EMAIL})..."
  # ssh-keygen will now prompt for passphrase naturally in the user's TTY
  ssh-keygen -t ed25519 -C "${KEY_EMAIL}" -f "$SSH_KEY_PATH"

  # 2. Add the key to the agent
  echo 'Adding newly generated key to ssh-agent (enter passphrase if set):'
  ssh-add "$SSH_KEY_PATH"

  if [ -s "${SSH_KEY_PATH}.pub" ]; then
    echo -e "${YELLOW}========================================================================${NC}"
    echo -e "ACTION REQUIRED: GITHUB"
    echo '1. Copy the public key below:'
    cat "${SSH_KEY_PATH}.pub"

    echo '2. Visit https://github.com/settings/keys'
    echo '3. Click "New SSH key" (Type: Authentication Key) and paste the key.'

    echo '4. Once the key is registered on GitHub, press [ENTER] to continue and test the connection.'
    echo -e "${YELLOW}========================================================================${NC}"
    read -r PAUSE
  else
    echo -e "${RED}❌ Fatal Error: Public key file (${SSH_KEY_PATH}.pub) is missing after generation. Aborting.${NC}"
    exit 1
  fi

else
  # --- EXISTING KEY FLOW ---
  echo -e "${GREEN}SSH key id_ed25519 already exists. Skipping generation.${NC}"

  # Attempt to add the existing key.
  echo 'Attempting to add existing key to agent (enter passphrase if set, or press ENTER if none):'
  ssh-add "$SSH_KEY_PATH" || echo 'Could not add key (it may already be added or passphrase was invalid).'
fi


# 4. Test SSH connection
echo -e "${GREEN}Testing GitHub SSH connection...${NC}"
SUCCESSFUL_CONNECTION=false
SSH_TEST_OUTPUT=$(ssh -T git@github.com 2>&1 || true)
echo "$SSH_TEST_OUTPUT"

if echo "$SSH_TEST_OUTPUT" | grep -q 'successfully authenticated'; then
    echo -e "${GREEN}✅ GitHub SSH connection successful!${NC}"
    SUCCESSFUL_CONNECTION=true
else
    echo -e "${RED}❌ GitHub SSH connection FAILED. Dotfiles clone aborted.${NC}"
    SUCCESSFUL_CONNECTION=false
fi

# --- STOW AND DOTFILES SETUP ---
echo -e "\n${GREEN}💻 Starting Dotfiles Setup with GNU Stow...${NC}"

mkdir -p "$BASE_DIR"

if $SUCCESSFUL_CONNECTION; then
    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo -e "${GREEN}Updating existing dotfiles repo...${NC}"
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        echo -e "${GREEN}Cloning dotfiles via SSH...${NC}"
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi

    if [ -d "$DOTFILES_DIR" ]; then
        rm -rf ~/.bash_logout ~/.bashrc

        # Stow all non-hidden directories
        cd $DOTFILES_DIR
        for dir in */; do
            case \"\$dir\" in
                .* | .*/ ) continue ;;
            esac
            echo "Stowing $dir"
            stow --restow --target="$HOME" "$dir"
        done

        echo -e "${GREEN}✅ Dotfiles Setup complete.${NC}"

        echo -e "\n${GREEN}Clearing fonts cache...${NC}"
        fc-cache -f
    fi
else
    echo -e "${RED}❌ Skipping Dotfiles clone because the SSH connection test failed.${NC}"
fi

echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}📦 Starting Modular User Application Installations...${NC}"
echo -e "${GREEN}========================================================================${NC}"

if [ ! -d "$USER_MODULES_DIR" ]; then
    echo -e "${RED}❌ Error: User modules directory '$USER_MODULES_DIR' not found.${NC}"
else
    # Find and execute each script in the user-modules directory
    for MODULE_PATH in "$USER_MODULES_DIR"/*.sh; do
        if [ -f "$MODULE_PATH" ]; then
            MODULE=$(basename "$MODULE_PATH")
            echo -e "\n${GREEN}--- Executing User Module: ${MODULE} ---${NC}"
            bash "$MODULE_PATH"
            echo -e "${GREEN}--- ${MODULE} finished. ---${NC}"
        fi
    done
fi

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 User Configuration & Apps Finished.${NC}"
echo -e "${GREEN}========================================================================${NC}"


echo -e "\n${GREEN}========================================================================${NC}"
echo -e "${GREEN}📦 Post-install INTERACTIVE configurations…${NC}"
echo -e "${GREEN}========================================================================${NC}"


echo -e "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: Whatsapp Web'
echo 'Visit >>>'
echo 'https://web.whatsapp.com/'
echo '<<<'
echo 'Install whatsapp web as a web PWA.'
echo 'When done, press [ENTER] to continue the script.'
echo -e "${YELLOW}========================================================================${NC}"

read -r PAUSE

echo -e "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: SyncThing'
echo 'Visit >>>'
echo 'http://127.0.0.1:8384/'
echo '<<<'
echo 'Settings: Enable ONLY local discovery'
echo 'Add devices using format tcp://x.x.x.x:22000, etc…'
echo 'When done, press [ENTER] to continue the script.'
echo -e "${YELLOW}========================================================================${NC}"

read -r PAUSE

echo -e "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: pCloud'
echo 'Visit >>>'
echo 'https://www.pcloud.com/how-to-install-pcloud-drive-linux.html?download=electron-64'
echo '<<<'
echo 'Download the pCloud AppImage, make it executable and run it.'
echo 'When done, press [ENTER] to continue the script.'
echo -e "${YELLOW}========================================================================${NC}"

read -r PAUSE

echo -e "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: AdGuard DNS'
echo 'Open Network Settings'
echo 'For each connection (ethernet, wireless), change the IPv4 and IPv6 settings:'
echo 'Method: Automatic (DHCP) addresses only'
echo 'DNS Servers: IPv4'
echo '94.140.14.15, 94.140.15.16'
echo 'DNS Servers: IPv6'
echo '2a10:50c0::bad1:ff, 2a10:50c0::bad2:ff'
echo 'Go to another terminal and run `sudo resolvectl flush-caches`'
echo 'Finally, disconnect then reconnect the internet connection.'
echo 'When done, press [ENTER] to continue the script.'
echo -e "${YELLOW}========================================================================${NC}"

read -r PAUSE

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 Post-install INTERACTIVE configurations finished! ${NC}"
echo -e "${GREEN}========================================================================${NC}"

echo -e "\n\n${GREEN}🎉🎉🎉 ALL DONE 🎉🎉🎉${NC}"
