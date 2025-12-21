#!/usr/bin/env bash
# Runs as non-root user.

set -euo pipefail

# --- INSTALLATION ---

echo 'Video DownloadHelper...'

curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash

echo 'Video DownloadHelper installation complete.'
