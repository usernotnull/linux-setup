#!/usr/bin/env bash
# Module to install Calibre via its official script.

echo "Starting Calibre installation..."

APP_PACKAGE="calibre"

# 1. Check if package is already installed
if command -v calibre &> /dev/null; then
    echo "✅ Calibre is already installed. Skipping."
    exit 0
fi

# 2. Install the package via official installer script
echo "Installing Calibre via official installer script..."

# Note: The Calibre script uses `sudo sh /dev/stdin` internally,
# but the execution must be piped from a non-sudo process for wget.
# We are already running the main script as sudo, but the Calibre script
# handles its own permissions checks (sudo -v) and execution flow.

wget -qO- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin

echo "Calibre installation complete."
