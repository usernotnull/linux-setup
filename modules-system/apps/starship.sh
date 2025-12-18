#!/usr/bin/env bash
# Module to install Starship (cross-shell prompt). Runs as root.

set -euo pipefail

echo "Installing Starship..."

# 1. Check if Starship is already installed
if command -v starship >/dev/null 2>&1; then
    echo "✅ Starship is already installed. Skipping."
    exit 0
fi

# 2. Install Starship
# The script automatically handles sudo if run by a user, but since we run as root,
# we can pass -y to auto-confirm and -b to specify the bin directory if needed,
# but the default behavior (install to /usr/local/bin) is perfect.
echo "Downloading and installing Starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo "Starship installation complete."
