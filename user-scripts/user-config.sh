#!/usr/bin/env bash
# Runs as non-root user. Handles SSH key setup and Dotfiles configuration.

set -euo pipefail

# Define path variables locally (using $HOME which is correct when run via 'su -')
BASE_DIR="$HOME/GitHub"
DOTFILES_DIR="$HOME/GitHub/dotfiles"
REPO_URL="git@github.com:usernotnull/dotfiles.git"

# --- GITHUB SSH KEY SETUP ---
echo '🔑 Starting GitHub SSH Key Setup...'

# 1. Generate SSH Key (Interactive input for email)
if [ ! -f ~/.ssh/id_ed25519 ]; then
  while [ -z "${KEY_EMAIL}" ]; do
    read -rp "Enter email for SSH key (required): " KEY_EMAIL
  done
  
  echo "Generating new ED25519 SSH key (${KEY_EMAIL})..."
  ssh-keygen -t ed25519 -C "${KEY_EMAIL}"
else
  echo 'SSH key id_ed25519 already exists. Skipping generation.'
fi

# 2. Start the ssh-agent and add the key
echo 'Starting SSH agent and adding key...'
eval "$(ssh-agent -s)"

# Fix: Use stty to hide passphrase input
echo -n 'Enter passphrase for ~/.ssh/id_ed25519: '
stty -echo
ssh-add ~/.ssh/id_ed25519
stty echo
echo # Add a newline after the hidden input

# 3. Instructions to add key to GitHub (Interactive step)
echo '========================================================================'
echo '‼️ ACTION REQUIRED: ADD SSH KEY TO GITHUB'
echo '1. Copy all the below line:'
cat ~/.ssh/id_ed25519.pub
echo '2. Visit https://github.com/settings/keys'
echo '3. Click "New SSH key" with type "Authentication Key" and paste the above.'
echo '4. When done, press [ENTER] to continue the script.'
echo '========================================================================'
read -r PAUSE

# 4. Test SSH connection
echo 'Testing GitHub SSH connection...'
ssh -T git@github.com
echo 'GitHub SSH Key Setup complete.'

# --- STOW AND DOTFILES SETUP ---
echo '💻 Starting Dotfiles Setup with GNU Stow...'

mkdir -p "$BASE_DIR"

if [ -d "$DOTFILES_DIR/.git" ]; then
    echo 'Updating existing dotfiles repo...'
    git -C "$DOTFILES_DIR" pull --ff-only
else
    echo 'Cloning dotfiles via SSH...'
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# Stow all non-hidden directories
cd "$DOTFILES_DIR"
for dir in */; do
    case "$dir" in
        .* | .*/ ) continue ;;
    esac
    echo "--- Stowing ${dir} ---"
    stow --adopt --restow --verbose "$dir" 2>&1
done
echo 'Dotfiles setup complete.'