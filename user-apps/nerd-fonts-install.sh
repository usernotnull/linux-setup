#!/usr/bin/env bash
# Script to install NerdFonts by calling a local submodule script

set -euo pipefail

# 1. Determine the directory where THIS script is located
# This resolves the absolute path to the directory containing this file.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# 2. Build the absolute path to the target install script
# Assuming 'NerdFonts' is a subdirectory inside the same folder as this script.
TARGET_SCRIPT="$SCRIPT_DIR/NerdFonts/install.sh"

echo "Installing NerdFonts (JetBrainsMono)..."

# 3. Check if the target script exists and is executable
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "❌ Error: NerdFonts installer not found at: $TARGET_SCRIPT"
    exit 1
fi

# 4. Execute the target script
# We pass the arguments directly.
bash "$TARGET_SCRIPT" -s JetBrainsMono

echo "NerdFonts installation complete."