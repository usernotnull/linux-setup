#!/usr/bin/env bash
# Runs as non-root user. Installs and configures Espanso AppImage.

set -euo pipefail

# --- ESPANSO INSTALLATION ---
ESPANSO_PATH="$HOME/opt/Espanso.AppImage"
echo 'Installing Espanso AppImage...'

# 1. Download/Check AppImage
if [ -f "$ESPANSO_PATH" ]; then
    echo "✅ Espanso AppImage already exists. Skipping download."
else
    mkdir -p "$HOME/opt"
    wget -qO "$ESPANSO_PATH" 'https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage'
    chmod u+x "$ESPANSO_PATH"
fi

# 2. Register Service (Requires sudo)
# NOTE: The outer orchestrator script runs this *as the user* but inside a context 
# where sudo is typically available via a previously established mechanism.
echo "Registering Espanso service..."
sudo "$ESPANSO_PATH" env-path register
espanso service register
espanso start

echo 'Espanso installation complete.'