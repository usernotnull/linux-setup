#!/usr/bin/env bash
# Module to orchestrate the installation of all root-level applications and tools.
# Runs every script found in the 'modules/apps' subdirectory. Runs as root.

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Exit immediately if a command exits with a non-zero status or variable is unset.
set -eu

# The location of the modular app scripts relative to the install.sh base directory
APPS_DIR="$(dirname "$(readlink -f "$0")")/apps"

echo -e "${GREEN}📦 Starting Modular Root Application Installations...${NC}"

# 1. Ensure the applications directory exists
if [ ! -d "$APPS_DIR" ]; then
    echo -e "${RED}❌ Error: Root application modules directory '${APPS_DIR}' not found. Aborting.${NC}"
    exit 1
fi

# 2. Find and execute each script in the applications directory, sorted alphabetically
for APP_SCRIPT in "$APPS_DIR"/*.sh; do
    
    # Check if the glob found actual files
    if [ ! -f "$APP_SCRIPT" ]; then
        if [[ "$APP_SCRIPT" == "$APPS_DIR/*.sh" ]]; then
            echo -e "${GREEN}⚠️ Warning: No root application scripts found in '${APPS_DIR}'. Skipping.${NC}"
        fi
        continue
    fi

    APP_NAME=$(basename "$APP_SCRIPT")

    echo -e "\n${GREEN}--- Executing Root App Module: ${APP_NAME} ---${NC}"
    
    # Execute the application module script
    bash "$APP_SCRIPT"
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Module ${APP_NAME} completed successfully.${NC}"
    else
      echo -e "${RED}❌ Module ${APP_NAME} failed. Aborting.${NC}"
      exit 1
    fi
    echo -e "${GREEN}--- ${APP_NAME} execution finished. ---${NC}"

done

echo -e "\n${GREEN}Root Application Installations Complete.${NC}"