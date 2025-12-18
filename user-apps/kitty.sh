#!/usr/bin/env bash
# Runs as non-root user. Installs Kitty terminal emulator.

set -euo pipefail

# --- KITTY TERMINAL INSTALLATION ---
echo 'Installing Kitty terminal emulator...'
KITTY_DIR="$HOME/.local/kitty.app"

if [ -d "$KITTY_DIR" ]; then
  echo "✅ Kitty is already installed in $KITTY_DIR. Skipping installation."
  exit 0
fi

echo "Downloading and installing Kitty..."

# The installer script handles downloading and placing files in ~/.local/kitty.app
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

echo "Creating symbolic links for 'kitty' and 'kitten'..."

# Ensure ~/.local/bin exists before creating links
mkdir -p "$HOME/.local/bin"

# Create symbolic links to add kitty and kitten to PATH (assuming ~/.local/bin is in
# your system-wide PATH)
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/

# Place the kitty.desktop file somewhere it can be found by the OS
cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/

# If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
# cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/

# Update the paths to the kitty and its icon in the kitty desktop file(s)
sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop

# Make xdg-terminal-exec (and hence desktop environments that support it use kitty)
echo 'kitty.desktop' > ~/.config/xdg-terminals.list

echo "Kitty installation complete."
