#!/usr/bin/env bash
# Module to configure user environment: SSH key generation and Dotfiles setup via Stow.

echo "🔑 Starting User Configuration: SSH Key Setup and Dotfiles..."

# Get the name of the original user who ran the sudo command
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(eval echo ~$TARGET_USER)

# --- USER-SPECIFIC COMMAND EXECUTION ---
su - "$TARGET_USER" -c "
  # --- GITHUB SSH KEY SETUP ---
  echo '🔑 Starting GitHub SSH Key Setup...'
  
  # 1. Generate SSH Key (using a placeholder email)
  # NOTE: The email 'rjfares@gmail.com' is a placeholder and should be updated by the user if needed.
  if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo 'Generating new ED25519 SSH key (rjfares@gmail.com)...'
    ssh-keygen -t ed25519 -C \"rjfares@gmail.com\"
  else
    echo 'SSH key id_ed25519 already exists. Skipping generation.'
  fi
  
  # 2. Start the ssh-agent and add the key
  echo 'Starting SSH agent and adding key...'
  eval \"\$(ssh-agent -s)\"
  ssh-add ~/.ssh/id_ed25519
  
  # 3. Instructions to add key to GitHub (Interactive step)
  echo '========================================================================'
  echo '‼️ ACTION REQUIRED: ADD SSH KEY TO GITHUB'
  echo '1. Copy the following public key:'
  cat ~/.ssh/id_ed25519.pub
  echo '2. Visit https://github.com/settings/keys'
  echo '3. Click \"New SSH key\" and paste the key copied above.'
  echo '4. When done, press [ENTER] to continue the script.'
  echo '========================================================================'
  read -r PAUSE
  
  # 4. Test SSH connection
  echo 'Testing GitHub SSH connection...'
  ssh -T git@github.com
  echo 'GitHub SSH Key Setup complete.'
  
  # --- STOW AND DOTFILES SETUP ---
  echo '💻 Starting Dotfiles Setup with GNU Stow...'
  
  BASE_DIR='${TARGET_HOME}/GitHub'
  DOTFILES_DIR='${TARGET_HOME}/GitHub/dotfiles'
  REPO_URL='git@github.com:usernotnull/dotfiles.git'

  mkdir -p \"$BASE_DIR\"

  if [ -d \"$DOTFILES_DIR/.git\" ]; then
      echo 'Updating existing dotfiles repo...'
      git -C \"$DOTFILES_DIR\" pull --ff-only
  else
      echo 'Cloning dotfiles via SSH...'
      git clone \"$REPO_URL\" \"$DOTFILES_DIR\"
  fi

  # Stow all non-hidden directories
  cd \"$DOTFILES_DIR\"
  for dir in */; do
      case \"\$dir\" in
          .* | .*/ ) continue ;;
      esac
      echo 'Stowing '$dir'...'
      stow --restow --target=\"$HOME\" \"\$dir\"
  done
  echo 'Dotfiles setup complete.'
"

echo "User configuration complete."