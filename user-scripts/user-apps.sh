#!/usr/bin/env bash
# Runs as non-root user.

set -euo pipefail

# --- ESPANSO INSTALLATION ---
ESPANSO_PATH="$HOME/opt/Espanso.AppImage"
echo 'Installing Espanso AppImage...'
if [ -f "$ESPANSO_PATH" ]; then
    echo "✅ Espanso AppImage already exists. Skipping download."
else
    mkdir -p "$HOME/opt"
    wget -qO "$ESPANSO_PATH" 'https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage'
    chmod u+x "$ESPANSO_PATH"
fi

# Service registration check (optional, as it's fast)
sudo "$ESPANSO_PATH" env-path register
espanso service register
espanso start
echo 'Espanso installation complete.'

# --- FLATPAK APPLICATION INSTALLATIONS ---
APP_IDS=(
  "org.audacityteam.Audacity"
  "org.videolan.VLC"
  "org.gnome.Rhythmbox3"
  "com.visualstudio.code"
  "com.brave.Browser"
  "md.obsidian.Obsidian"
  "org.qbittorrent.qBittorrent"
  "com.github.dynobo.normcap"
)

echo "Starting Flatpak Installations (Checking for existing installations)..."

for APP_ID in "${APP_IDS[@]}"; do
  # Check if the Flatpak application is already installed (system-wide or per-user)
  if flatpak info --installed "${APP_ID}" >/dev/null 2>&1; then
    echo "✅ ${APP_ID} is already installed. Skipping."
  else
    echo "Installing ${APP_ID}..."
    flatpak install -y flathub "${APP_ID}"
  fi
done

# Run Obsidian once if installed
if flatpak info --installed md.obsidian.Obsidian >/dev/null 2>&1; then
  echo "Running Obsidian once to set up user configuration..."
  flatpak run md.obsidian.Obsidian &
fi
echo 'Flatpak applications installed.'

# --- EMOJI FONT INSTALLATION ---
FONT_DIR="$HOME/.local/share/fonts/Twemoji" # A directory created by the install script
echo 'Installing Twitter Color Emoji Font...'

if [ -d "$FONT_DIR" ]; then
    echo "✅ Twitter Emoji Font appears to be installed (found $FONT_DIR). Skipping."
else
    echo "Downloading and installing font..."
    # Using the wget command from your 04-userapps.sh (with version)
    wget -nv https://github.com/13rac1/twemoji-color-font/releases/download/v15.1.0/TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
    
    # Check if download succeeded
    if [ ! -f TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz ]; then
        echo "❌ Font download failed. Skipping font installation."
    else
        tar zxf TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
        
        cd TwitterColorEmoji-SVGinOT-Linux-15.1.0
        ./install.sh # This installs the font to $HOME/.local/share/fonts
        cd ..
        
        # Clean up the downloaded files
        rm -rf TwitterColorEmoji-SVGinOT-Linux-15.1.0 TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
    fi
fi
echo "Emoji Font installation complete."