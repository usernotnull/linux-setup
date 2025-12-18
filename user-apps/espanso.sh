#!/usr/bin/env bash
# Runs as non-root user. Installs and configures Espanso AppImage.

set -euo pipefail

echo "Starting Espanso (Wayland) USER installation (2/2)..."

espanso service register
espanso start

echo 'Espanso installation complete.'

