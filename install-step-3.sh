#!/usr/bin/env bash

# Define colors for status messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🔑 Final Customizations...${NC}"
echo -e "${GREEN}========================================================================${NC}"

echo "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: Espanso'
echo 'Run the below command in another terminal:'
echo '>>>'
echo 'espanso service register && espanso start'
echo '<<<'
echo 'When done, press [ENTER] to continue the script.'
echo "${YELLOW}========================================================================${NC}"

echo "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: Brave'
echo 'Open Brave > Settings > Sync'
echo 'When done, press [ENTER] to continue...'
echo "${YELLOW}========================================================================${NC}"

read -r PAUSE

echo "${YELLOW}========================================================================${NC}"
echo 'ACTION REQUIRED: SyncThing'
echo 'Visit: http://127.0.0.1:8384/'
echo 'Settings: Enable ONLY local discovery'
echo 'Add devices using format tcp://x.x.x.x:22000, etc…'
echo 'When done, press [ENTER] to continue the script.'
echo "${YELLOW}========================================================================${NC}"

read -r PAUSE

espanso service register && espanso start

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}🎉 ALL DONE!${NC}"
echo -e "${GREEN}========================================================================${NC}"
