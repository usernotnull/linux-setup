#!/usr/bin/env bash
# Module to copy user-specific scripts to a temporary location and execute them
# as the non-root user.

echo "Starting Execution of User-Specific Scripts..."

# 1. Define target user variables
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(eval echo ~$TARGET_USER)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/../user-scripts"
TEMP_DIR="/tmp/${TARGET_USER}_setup"

# 2. Copy scripts to a temporary location accessible by the user
mkdir -p "$TEMP_DIR"
cp -r "$SCRIPT_DIR/." "$TEMP_DIR"

# 3. Execute the user configuration script first
echo "Executing User Configuration (SSH, Stow, Dotfiles)..."
su - "$TARGET_USER" -c "bash $TEMP_DIR/user-config.sh"

# 4. Execute the user applications script second
echo "Executing User Applications (Espanso, Flatpaks, Emojis)..."
su - "$TARGET_USER" -c "bash $TEMP_DIR/user-apps.sh"

# 5. Clean up temporary directory (Optional, but clean)
rm -rf "$TEMP_DIR"

echo "User-Specific Scripts finished."