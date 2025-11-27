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
    
    # Download and dearmor the key
    wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
    
    # Add the repository to the list of repositories:
    echo "Adding Signal Desktop repository source..."
    # Download the repository source file and place it in sources.list.d
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" | tee "${REPO_FILE}" > /dev/null
else
    echo "Signal repository already configured. Skipping key and repo addition."
fi

# 3. Update your package database and install Signal:
echo "Updating package database and installing signal-desktop..."
apt update -qq && apt install -y "${APP_PACKAGE}"

echo "Signal Desktop installation complete."