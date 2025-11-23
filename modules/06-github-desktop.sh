#!/usr/bin/env bash
# Module to install GitHub Desktop for Linux via the Shiftkey PPA.

echo "Installing GitHub Desktop..."

# 1. Get the @shiftkey package feed GPG key and add it to keyrings
echo "Adding Shiftkey GPG key..."
wget -qO - https://apt.packages.shiftkey.dev/gpg.key | gpg --dearmor | tee /usr/share/keyrings/shiftkey-packages.gpg > /dev/null

# 2. Add the repository to the sources list
echo "Adding Shiftkey repository to sources.list.d..."
sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/shiftkey-packages.gpg] https://apt.packages.shiftkey.dev/ubuntu/ any main" > /etc/apt/sources.list.d/shiftkey-packages.list'

# 3. Update the package lists and install github-desktop
echo "Updating package lists and installing github-desktop..."
apt update && apt install -y github-desktop

echo "GitHub Desktop installation complete."