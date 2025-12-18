#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# Main Installation Script
# Executes installation modules sequentially by finding and running all *.sh files
# in the MODULES_DIR, ensuring execution order by sorting.
#-------------------------------------------------------------------------------

# Define colors for status messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Exit immediately if a command exits with a non-zero status or variable is unset.
set -eu

# Define the directory where main stage modules are stored
MODULES_DIR="$(dirname "$(readlink -f "$0")")/modules-system"

# Ensure script is run with sudo permissions
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Please run the main script with sudo: sudo ./install.sh${NC}"
  exit 1
fi

# Function to execute modules
execute_modules() {
  echo -e "${GREEN}🚀 Starting modular installation...${NC}"
  
  # Update package lists first
  echo -e "${GREEN}🔄 Updating APT package lists...${NC}"
  apt update -qq
  
  # Find all .sh files directly in MODULES_DIR, sort them (for 01-*, 02-*, etc. order), and execute.
  find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" | sort | while read -r module; do
    
    if [ -f "$module" ]; then
      echo -e "\n${GREEN}====================================================${NC}"
      echo -e "${GREEN}▶️  Executing module: $(basename "$module")${NC}"
      echo -e "${GREEN}====================================================${NC}"
      
      # Execute the module script
      bash "$module"
      
      if [ $? -eq 0 ]; then
        # echo -e "${GREEN}✅ Module $(basename "$module") completed successfully.${NC}"
        continue
      else
        echo -e "${RED}❌ Module $(basename "$module") failed. Aborting.${NC}"
        exit 1
      fi
    fi
  done
  
  echo -e "\n${GREEN}✨ All modules finished! System setup complete.${NC}"
}

# Run the main execution function
execute_modules
#-------------------------------------------------------------------------------