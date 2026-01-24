#!/usr/bin/env bash
# Module to install rhythmbox (powerful batch renamer for KDE). Runs as root.

echo "Starting rhythmbox installation..."

APP_PACKAGE="rhythmbox"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ rhythmbox is already installed. Skipping."
    exit 0
fi

# 2. Install the package
echo "Updating package index silently and installing rhythmbox..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo "rhythmbox installation complete."
