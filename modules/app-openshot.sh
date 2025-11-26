#!/usr/bin/env bash
# Module to install OpenShot via PPA. Runs as root.

echo "Starting OpenShot installation..."

# Package name for the check
APP_PACKAGE="openshot-qt"
PPA_REPO="ppa:openshot.developers/ppa"

# 1. Check if package is already installed
if dpkg -l | grep -q "^ii.*${APP_PACKAGE}"; then
    echo "✅ OpenShot is already installed. Skipping."
    exit 0
fi

# 2. Add PPA if not already added
if ! grep -q "${PPA_REPO}" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    echo "Adding OpenShot PPA: ${PPA_REPO}..."
    add-apt-repository -y "${PPA_REPO}"
else
    echo "OpenShot PPA already configured. Skipping PPA addition."
fi

# 3. Install the package
echo "Installing openshot-qt and python3-openshot..."
apt update -qq && apt install -y openshot-qt python3-openshot

echo "OpenShot installation complete."