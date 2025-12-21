#!/usr/bin/env bash
# Module to install KRename (powerful batch renamer for KDE). Runs as root.

echo "Starting KRename installation..."

APP_PACKAGE="krename"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ KRename is already installed. Skipping."
    exit 0
fi

# 2. Install the package
echo "Updating package index silently and installing KRename..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo "KRename installation complete."
