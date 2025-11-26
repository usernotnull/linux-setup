# 🚀 Linux System Setup

This repository contains a modular, automated bash script pipeline for setting up a customized Linux environment (primarily targeting Debian/Ubuntu-based systems).

This system separates installation, configuration, and user application setup into distinct, manageable modules.

## ✨ Features

- **Modular Design:** Separate scripts for APT packages, system configuration, third-party repositories, and user applications (Flatpak, AppImage).
- **Automated Installation:** Installs a wide range of essential software, drivers, and utilities in one go.
- **System Configuration:** Handles core configurations like TLP (Power Management) and UFW (Firewall) rules.
- **User-Specific Setup:** Installs user-level applications (like Espanso and Flatpaks) into the correct user profile, even when the main script runs as root.
- **Dynamic Downloads:** Automatically finds and downloads the latest versions of GitHub releases (e.g., ripgrep, fastfetch).

## 📦 Installation Pipeline Overview

The main script executes the following modules sequentially:

1.  **`01-packages.sh`**: Installs core APT dependencies (e.g., `ufw`, `flatpak`, `gparted`, CUDA tools).
2.  **`02-config.sh`**: Configures system services (enables TLP) and applies system fixes (removes `gstreamer1.0-vaapi`). **Also configures UFW rules for Syncthing ports.**
3.  **`03-+`** All other repos

## 💻 How to Run

To set up a new machine, use the following one-liner command to download, extract, and execute the installation pipeline.

**PREREQUISITES:** You must have `wget` and `unzip` installed.

```bash
# 1. Install prerequisites (if needed)
sudo apt update -qq && sudo apt install -y wget unzip && \
# 2. Define variables
USER="usernotnull" && REPO="linux-setup" && \
# 3. Download, extract, and run the main script
wget -q "[https://github.com/$](https://github.com/${USER}/${REPO}/archive/main.zip" -O "${REPO}.zip" && \
unzip -q "${REPO}.zip" && \
cd "${REPO}-main" && \
sudo ./install.sh && \
# 4. Cleanup
cd .. && rm -rf "${REPO}-main" "${REPO}.zip"
```
