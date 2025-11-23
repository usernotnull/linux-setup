#!/usr/bin/env bash
# Module to install OpenShot Video Editor via its official PPA.

echo "Installing OpenShot Video Editor..."

# 1. Add the OpenShot PPA repository
echo "Adding openshot.developers/ppa repository..."
add-apt-repository -y ppa:openshot.developers/ppa

# 2. Update the package database to include the new repository
echo "Updating package database..."
apt update

# 3. Install openshot-qt and the required python library
echo "Installing openshot-qt and python3-openshot..."
apt install -y openshot-qt python3-openshot

echo "OpenShot installation complete."