#!/usr/bin/env bash
# Module to install Calibre via its official script.

echo "Installing Calibre via official installer script..."

# Note: The Calibre script uses `sudo sh /dev/stdin` internally, 
# but the execution must be piped from a non-sudo process for wget.
# We are already running the main script as sudo, but the Calibre script 
# handles its own permissions checks (sudo -v) and execution flow.

wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin

echo "Calibre installation complete."