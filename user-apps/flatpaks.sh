#!/usr/bin/env bash
# Runs as non-root user. Installs all required Flatpak applications with idempotency.

set -euo pipefail

# 1. Add Flathub remote (user scope) if it doesn't exist
# This ensures the user has access to the repository even if not added system-wide
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# --- FLATPAK APPLICATION INSTALLATIONS ---
# List of standard apps to install
APP_IDS=(
  "org.audacityteam.Audacity"
  "org.videolan.VLC"
  "org.gnome.Rhythmbox3"
  "md.obsidian.Obsidian"
  "org.qbittorrent.qBittorrent"
  "com.github.dynobo.normcap"
  "com.bitwarden.desktop"
  "org.freeplane.App"
  "org.cryptomator.Cryptomator"
  "org.gnome.meld"
  "org.gimp.GIMP"
  "org.kde.krita"
  "org.kde.digikam"
  "com.belmoussaoui.Decoder"
)

echo "Starting Flatpak Installations (Checking for existing installations)..."

for APP_ID in "${APP_IDS[@]}"; do
  # Check if the Flatpak application is already installed (system-wide or per-user)
  if flatpak info --installed "${APP_ID}" >/dev/null 2>&1; then
    echo "✅ ${APP_ID} is already installed. Skipping."
  else
    echo "Installing ${APP_ID}..."
    # -y is for non-interactive installation
    # Using --user explicitly to force user-level installation
    flatpak install --user -y flathub "${APP_ID}"
  fi
done

echo 'Flatpak applications installed.'
