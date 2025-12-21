#!/usr/bin/env bash
# Module to install Signal Desktop via its official APT repository.

echo "Installing Signal Desktop messenger..."

APP_PACKAGE="signal-desktop"
REPO_FILE="/etc/apt/sources.list.d/signal-desktop.sources"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ Signal Desktop is already installed. Skipping installation."
    exit 0
fi

# 2. Add repository only if the source file does not exist
if [ ! -f "${REPO_FILE}" ]; then
    echo "Adding Signal Desktop signing key..."
    
    # 1. Install our official public software signing key:
    wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg;
    cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

    # 2. Add our repository to your list of repositories:
    wget -O signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources;
    cat signal-desktop.sources | sudo tee "${REPO_FILE}" > /dev/null
else
    echo "Signal repository already configured. Skipping key and repo addition."
fi

# 3. Update your package database and install Signal:
echo "Updating package database and installing signal-desktop..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo "Signal Desktop installation complete."