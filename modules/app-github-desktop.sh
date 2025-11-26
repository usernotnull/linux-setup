#!/usr/bin/env bash
# Module to install GitHub Desktop via PPA. Runs as root.

echo "Starting GitHub Desktop installation..."

# Package name for the check
APP_PACKAGE="github-desktop"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ GitHub Desktop is already installed. Skipping."
    exit 0
fi

# 2. Add PPA if not already added (Checking for the MWT mirror domain)
if ! grep -q "mirror.mwt.me" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    echo "Adding GitHub Desktop APT Repository (MWT Mirror)..."
    
    # 2a. Add the GPG key for the repository
    # Fetches the key silently, de-armors it, and installs it to the keyrings directory.
    wget -qO - https://mirror.mwt.me/shiftkey-desktop/gpgkey | gpg --dearmor | tee /usr/share/keyrings/mwt-desktop.gpg > /dev/null
    
    # 2b. Add the repository source list
    # Uses dynamic architecture detection for broader compatibility.
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mwt-desktop.gpg] https://mirror.mwt.me/shiftkey-desktop/deb/ any main" | tee /etc/apt/sources.list.d/mwt-desktop.list >/dev/null
else
    echo "GitHub Desktop APT repository already configured (MWT Mirror). Skipping repository addition."
fi

# 3. Install the package
echo "Updating package index silently and installing GitHub Desktop..."
# apt update -qq is used for a silent update.
apt update -qq && apt install -y "${APP_PACKAGE}"

echo "GitHub Desktop installation complete."