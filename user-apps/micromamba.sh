#!/usr/bin/env bash
# Runs as non-root user. Installs Micromamba (fast Mamba package manager).

set -euo pipefail

# 1. Check if Micromamba is already installed
# The installer typically places the binary in ~/.local/bin/micromamba
MICROMAMBA_BIN="$HOME/.local/bin/micromamba"

if [ -f "$MICROMAMBA_BIN" ]; then
    echo "✅ Micromamba is already installed at $MICROMAMBA_BIN. Skipping."
    exit 0
fi

# 2. Optional installation check
echo "===================================================="
echo "Micromamba is an optional fast package manager."
read -rp "Do you want to install Micromamba? (y/N): " CONFIRM
echo "===================================================="

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Skipping Micromamba installation as requested."
    exit 0
fi

# 3. Install Micromamba
echo "Downloading and installing Micromamba..."
# We use the user's SHELL environment variable as requested
"${SHELL}" <(curl -L micro.mamba.pm/install.sh)

echo "Micromamba installation complete."
