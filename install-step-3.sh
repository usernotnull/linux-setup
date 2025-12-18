#!/usr/bin/env bash

# Define colors for status messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================================================${NC}"
echo -e "${YELLOW}🔑 Final Customizations...${NC}"
echo -e "${YELLOW}========================================================================${NC}"

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Set Keyboard Shortcut'
echo 'Add the below command as a keyboard shortcut:'
which kitty
echo 'When done, press [ENTER] to continue the script.'
echo '========================================================================'

read -r PAUSE

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Add the Brave Sync Chain'
echo 'Open Brave > Settings > Sync'
echo 'When done, press [ENTER] to continue...'
echo '========================================================================'

read -r PAUSE

echo '========================================================================'
echo '‼️ ACTION REQUIRED: Add your device to the sync network'
echo 'Visit: http://127.0.0.1:8384/'
echo 'Settings: Enable ONLY local discovery'
echo 'Add devices using format tcp://x.x.x.x:22000, etc…'
echo 'When done, press [ENTER] to continue the script.'
echo '========================================================================'

read -r PAUSE

echo -e "${YELLOW}========================================================================${NC}"
echo -e "${YELLOW}🎉 ALL DONE!${NC}"
echo -e "${YELLOW}========================================================================${NC}"
