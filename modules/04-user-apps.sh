#!/usr/bin/env bash
# Module to orchestrate the installation of all user-specific applications by running 
# every script found in the 'user-apps' directory.

echo "📦 Starting Modular User Application Installations..."

# Get the name of the original user who ran the sudo command
TARGET_USER=${SUDO_USER:-$(whoami)}
MODULES_DIR="./modules/user-apps" # Folder containing the individual user app scripts

# 1. Ensure the user-specific modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    echo "❌ Error: User application modules directory '${MODULES_DIR}' not found. Aborting."
    exit 1
fi

# 2. Find and execute each script in the modules directory, sorted alphabetically
# Globs the *.sh files. Execution will be in alphabetical order (e.g., user-app-espanso.sh first).
for MODULE_PATH in "$MODULES_DIR"/*.sh; do
    
    # Check if the glob found actual files (it will expand to the literal pattern if no files match)
    if [ ! -f "$MODULE_PATH" ]; then
        # This occurs if the directory is empty or the pattern matches nothing.
        # We can add an explicit warning if this is the first file.
        if [[ "$MODULE_PATH" == "$MODULES_DIR/*.sh" ]]; then
            echo "⚠️ Warning: No application scripts found in '${MODULES_DIR}'. Skipping."
        fi
        continue
    fi

    MODULE=$(basename "$MODULE_PATH")

    echo ""
    echo "--- Executing User App Module: ${MODULE} ---"
    
    # Use 'su' to execute the module script as the TARGET_USER
    # 'bash ${MODULE_PATH}' executes the script, allowing it to correctly use $HOME
    su - "$TARGET_USER" -c "bash \"$MODULE_PATH\""
    
    echo "--- ${MODULE} execution finished. ---"

done

echo ""
echo "User Application Installations Complete."