#!/usr/bin/env bash
# Runs as non-root user. Installs all required Flatpak applications with idempotency.

set -euo pipefail

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
    # -y is for non-interactive installation
    flatpak install -y flathub "${APP_ID}"
  fi
done

# Run Obsidian once if installed (for configuration files)
if flatpak info --installed md.obsidian.Obsidian >/dev/null 2>&1; then
  echo "Running Obsidian once to set up user configuration..."
  # Run in background to not block the script
  flatpak run md.obsidian.Obsidian &
fi

echo 'Flatpak applications installed.'