#!/usr/bin/env bash
# Module to configure system services and apply fixes.

echo "Starting system configuration…"

# Enable TLP (Power Management) Service
# echo "Enabling TLP service to start on boot…"
# systemctl enable tlp

# --- Firewall Configuration (System Protection) ---
echo "Configuring UFW firewall rules for Syncthing access (System Protection)…"
# Allow Syncthing's default TCP port for synchronization
echo "Allowing TCP port 22000 (Syncthing Synchronization)…"
ufw allow 22000/tcp
# Allow Syncthing's default UDP port for discovery
echo "Allowing UDP port 21027 (Syncthing Discovery)…"
ufw allow 21027/udp

echo "Setting default file associations…"

grep -E '^(audio/|video/)' /usr/share/mime/types | xargs xdg-mime default vlc.desktop
grep -E '^(text/|application/(javascript|json|xml|x-shellscript|x-yaml|x-python|x-php|x-perl|x-ruby))' /usr/share/mime/types | xargs xdg-mime default code.desktop

echo "System configuration complete."
