#!/usr/bin/env bash
# Module to install all user-specific applications (Espanso, Flatpak apps, and fonts).

echo "📦 Starting User Application Installations..."

# Get the name of the original user who ran the sudo command
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(eval echo ~$TARGET_USER)

# --- USER-SPECIFIC COMMAND EXECUTION ---
su - "$TARGET_USER" -c "
  # --- ESPANSO INSTALLATION ---
  echo 'Installing Espanso AppImage...'
  mkdir -p $TARGET_HOME/opt
  wget -qO $TARGET_HOME/opt/Espanso.AppImage 'https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage'
  chmod u+x $TARGET_HOME/opt/Espanso.AppImage
  # The env-path registration requires sudo
  sudo $TARGET_HOME/opt/Espanso.AppImage env-path register
  espanso service register
  espanso start

  # --- FLATPAK APPLICATION INSTALLATIONS ---
  
  echo 'Installing Audacity via Flatpak...'
  flatpak install -y flathub org.audacityteam.Audacity
  
  echo 'Installing VLC via Flatpak...'
  flatpak install -y flathub org.videolan.VLC
  
  echo 'Installing Rhythmbox via Flatpak...'
  flatpak install -y flathub org.gnome.Rhythmbox3
  
  echo 'Installing VS Code via Flatpak...'
  flatpak install -y flathub com.visualstudio.code
  
  echo 'Installing Brave Browser via Flatpak...'
  flatpak install -y flathub com.brave.Browser
  
  echo 'Installing Obsidian via Flatpak...'
  flatpak install -y flathub md.obsidian.Obsidian
  flatpak run md.obsidian.Obsidian & # Run once to set up configuration files in user's home
  
  echo 'Installing KTorrent via Flatpak...'
  flatpak install -y flathub org.kde.ktorrent
  
  echo 'Installing Normcap (OCR) via Flatpak...'
  flatpak install -y flathub com.github.dynobo.normcap

  # --- EMOJI FONT INSTALLATION ---
  echo 'Installing Twitter Color Emoji Font...'
  wget -q https://github.com/13rac1/twemoji-color-font/releases/latest/download/TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
  tar zxf TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
  
  cd TwitterColorEmoji-SVGinOT-Linux-15.1.0
  ./install.sh
  
  # Clean up the downloaded files
  cd ..
  rm -rf TwitterColorEmoji-SVGinOT-Linux-15.1.0 TwitterColorEmoji-SVGinOT-Linux-15.1.0.tar.gz
"

echo "User application installation complete."