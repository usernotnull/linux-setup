#!/usr/bin/env bash
# Runs as non-root user. Installs Kitty terminal emulator.

set -euo pipefail

# --- KITTY TERMINAL INSTALLATION ---
echo 'Installing Kitty terminal emulator...'
KITTY_DIR="$HOME/.local/kitty.app"

if [ -d "$KITTY_DIR" ]; then
  echo "✅ Kitty is already installed in $KITTY_DIR. Skipping installation."
else
  echo "Downloading and installing Kitty..."
  
  # The installer script handles downloading and placing files in ~/.local/kitty.app
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  
  echo "Creating symbolic links for 'kitty' and 'kitten'..."
  
  # Ensure ~/.local/bin exists before creating links
  mkdir -p "$HOME/.local/bin"
  
  # Create symbolic links in $HOME/.local/bin so 'kitty' can be run directly
  ln -sf "$KITTY_DIR/bin/kitty" "$HOME/.local/bin/kitty"
  ln -sf "$KITTY_DIR/bin/kitten" "$HOME/.local/bin/kitten"
  
  echo "Kitty installation complete."
fi