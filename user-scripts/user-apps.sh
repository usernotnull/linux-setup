#!/usr/bin/env bash
# Runs as non-root user. Handles app installs (Espanso, Flatpak) and fonts.

set -euo pipefail

# --- ESPANSO INSTALLATION ---
# $HOME is automatically correct. We use sudo because env-path register requires it.
echo 'Installing Espanso AppImage...'
mkdir -p $HOME/opt
wget -qO $HOME/opt/Espanso.AppImage 'https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage'
chmod u+x $HOME/opt/Espanso.AppImage
# The env-path registration requires sudo
sudo $HOME/opt/Espanso.AppImage env-path register
espanso service register
espanso start

# --- FLATPAK APPLICATION INSTALLATIONS ---

echo 'Installing Audacity via Flatpak...'
flatpak install -y flathub org.audacityteam.Audacity
# ... (rest of the Flatpak installs remain the same)
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
flatpak run md.obsidian.Obsidian & 
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