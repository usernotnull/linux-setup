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

    echo '========================================================================'
    echo '‼️ ACTION REQUIRED: Register & Start Espanso service'
    echo 'Run the below command in another terminal:'
    echo '>>>'
    echo "sudo \"$ESPANSO_PATH\" env-path register; espanso service register; espanso start"
    echo '<<<'
    echo 'When done, press [ENTER] to continue the script.'
    echo '========================================================================'
    
    read -r PAUSE
    echo 'Espanso installation complete.'
fi
