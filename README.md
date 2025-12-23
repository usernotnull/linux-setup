# 🚀 Linux System Setup

This repository contains a modular, automated bash script pipeline for setting up a customized Linux environment (primarily targeting Debian/Ubuntu-based systems).

This system separates installation, configuration, and user application setup into distinct, manageable modules.

## ✨ Features

- **Modular Design:** Separate scripts for APT packages, system configuration, third-party repositories, and user applications (Flatpak, AppImage).
- **Automated Installation:** Installs a wide range of essential software, drivers, and utilities in one go.
- **System Configuration:** Handles core configurations like TLP (Power Management) and UFW (Firewall) rules.
- **User-Specific Setup:** Installs user-level applications (like Espanso and Flatpaks) into the correct user profile, even when the main script runs as root.
- **Dynamic Downloads:** Automatically finds and downloads the latest versions of GitHub releases (e.g., ripgrep, fastfetch).

## 💻 How to Run

To set up a new machine, use the following one-liner command to download, extract, and execute the installation pipeline.

```bash
sudo apt update -qq && sudo apt install -y wget unzip && \
wget -q "https://github.com/usernotnull/linux-setup/archive/main.zip" -O "linux-setup.zip" && \
unzip -q "linux-setup.zip" && \
sudo "./linux-setup-main/install-step-1-as-sudo.sh" && \
"./linux-setup-main/install-step-2-as-user.sh" && \
rm -rf "linux-setup-main" "linux-setup.zip"
```
