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
# 1. Install prerequisites (if needed)
sudo apt update -qq && sudo apt install -y wget unzip && \
# 2. Define variables
USER="usernotnull" && REPO="linux-setup" && \
# 3. Download and extract
wget -q "https://github.com/${USER}/${REPO}/archive/main.zip" -O "${REPO}.zip" && \
unzip -q "${REPO}.zip" && \
# 4. Run the scripts using absolute/relative paths
sudo "./${REPO}-main/install-step-1-as-sudo.sh" && \
"./${REPO}-main/install-step-2-as-user.sh" && \
"./${REPO}-main/install-step-3.sh" && \
# 5. Cleanup
rm -rf "${REPO}-main" "${REPO}.zip"
```
