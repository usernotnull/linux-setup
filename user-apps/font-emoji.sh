#!/usr/bin/env bash
# Runs as non-root user. Installs the Twitter Color Emoji Font.

set -euo pipefail

# --- EMOJI FONT INSTALLATION ---
FONT_VERSION="15.1.0"
FONT_DIR="$HOME/.local/share/fonts/TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}"
TAR_FILE="TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}.tar.gz"

echo 'Installing Twitter Color Emoji Font...'

# The install.sh script often creates a specific directory. 
# We check for a common artifact to determine idempotency.
if [ -d "$FONT_DIR" ]; then
    echo "✅ Twitter Emoji Font appears to be installed. Skipping."
else
    echo "Downloading and installing font..."
    
    # Download the specific version
    wget -nq https://github.com/13rac1/twemoji-color-font/releases/download/v${FONT_VERSION}/${TAR_FILE}
    
    # Check if download succeeded
    if [ ! -f "$TAR_FILE" ]; then
        echo "❌ Font download failed. Skipping font installation."
    else
        tar zxf "$TAR_FILE"
        
        cd "TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}"
        ./install.sh # This installs the font to $HOME/.local/share/fonts
        cd ..
        
        # Clean up the downloaded files
        rm -rf "TwitterColorEmoji-SVGinOT-Linux-${FONT_VERSION}" "$TAR_FILE"
        
        # Refresh font cache
        fc-cache -f -v > /dev/null 2>&1

        echo "Emoji Font installation complete."
    fi
fi
