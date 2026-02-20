#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Installs Docker Engine via the official APT repository.
#              Must be run directly as root (not via sudo).
#              Idempotent - safe to run multiple times.
# USAGE:       su -c "./install-docker-system.sh"
#              or: su - root, then ./install-docker-system.sh
# REQUIREMENTS: gum, curl, apt-get, dpkg, systemctl
# NOTES:       Run this script first, as root.
#              After this completes, log in as your normal user and run:
#              ./install-docker-rootless.sh
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_VERSION="1.0.0"

DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
    docker-ce-rootless-extras
)

KEYRING_DIR="/etc/apt/keyrings"
KEYRING_FILE="${KEYRING_DIR}/docker.asc"
KEYRING_URL="https://download.docker.com/linux/ubuntu/gpg"
REPO_FILE="/etc/apt/sources.list.d/docker.sources"

LOG_DIR="/var/log/install-docker"
LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d_%H-%M-%S")_system.log"

# === HELPERS ===
check_dependencies() {
    local missing_deps=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing_deps+=("$cmd")
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        gum style --foreground 196 --border double --border-foreground 196 \
            --padding "1 2" "ERROR: Missing dependencies:" \
            "" "$(printf '  - %s\n' "${missing_deps[@]}")"
        exit 1
    fi
}

die() {
    log_message "ERROR: $*"
    gum style --foreground 196 --border double --border-foreground 196 \
        --padding "1 2" "ERROR: $*"
    exit 1
}

warn() {
    log_message "WARNING: $*"
    gum style --foreground 214 --border normal --border-foreground 214 \
        --padding "0 1" "WARNING: $*"
}

success() {
    log_message "SUCCESS: $*"
    gum style --foreground 76 "$*"
}

info() {
    log_message "INFO: $*"
    gum style --foreground 39 "$*"
}

log_message() {
    [ -n "${1:-}" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
}

setup_logging() {
    mkdir -p "$LOG_DIR" || die "Failed to create log directory: $LOG_DIR"
    rotate_logs
    log_message "=== Session started ==="
    trap 'log_message "=== Session ended (exit: $?) ==="' EXIT
}

rotate_logs() {
    local log_count
    log_count=$(find "$LOG_DIR" -name "*_system.log" -type f 2>/dev/null | wc -l)

    if [ "$log_count" -gt 10 ]; then
        find "$LOG_DIR" -name "*_system.log" -type f -printf '%T+ %p\n' |
            sort | head -n -10 | cut -d' ' -f2- |
            xargs -r rm -f
    fi
}

is_package_installed() {
    dpkg -l 2>/dev/null | grep "^ii.*${1}" >/dev/null 2>&1
}

get_package_version() {
    dpkg -l 2>/dev/null | grep "^ii.*${1}" | awk '{print $3}' 2>/dev/null || true
}

# === HEADER ===
gum style --border double --border-foreground 33 --padding "1 2" --margin "1 0" \
    "Docker Engine Installer v${SCRIPT_VERSION} - System Setup" \
    "" \
    "Step 1 of 2: Installs Docker packages via the official APT repository." \
    "Run as root. After this completes, run install-docker-rootless.sh as your user."

# === LOGGING & DEPENDENCIES ===
setup_logging
check_dependencies gum curl dpkg apt-get systemctl

printf "Install Docker? [y/N]: "
read -r confirm
echo

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log "$ICON_WARN" "Restore cancelled by user"
    exit 0
fi

# === PRIVILEGE CHECK ===
if [ "$EUID" -ne 0 ]; then
    warn "This script requires root privileges for installation"
    die "Please run with sudo: sudo $0"
fi

# === ALREADY INSTALLED CHECK ===
if is_package_installed "docker-ce"; then
    success "Docker Engine is already installed"

    installed_version=""
    installed_version=$(get_package_version "docker-ce")
    if [ -n "$installed_version" ]; then
        info "Installed version: $installed_version"
    fi

    echo ""
    gum style --border rounded --border-foreground 76 --padding "0 2" \
        "Nothing to do - Docker Engine is already installed." \
        "" \
        "If rootless mode is not yet set up, run: ./install-docker-rootless.sh"
    exit 0
fi

# === PREREQUISITES ===
if gum spin --spinner dot --title "Installing prerequisites (ca-certificates, curl)..." -- \
    apt-get install -y ca-certificates curl; then
    success "Prerequisites installed"
else
    die "Failed to install prerequisites"
fi
echo ""

# === UIDMAP CHECK ===
# uidmap provides newuidmap/newgidmap, required for rootless Docker user namespace mapping.
if command -v newuidmap >/dev/null 2>&1 && command -v newgidmap >/dev/null 2>&1; then
    info "uidmap already installed ($(newuidmap --version 2>&1 || true))"
else
    warn "uidmap not found - required for rootless Docker user namespace mapping"
    if gum spin --spinner dot --title "Installing uidmap..." -- \
        apt-get install -y uidmap; then
        success "uidmap installed"
    else
        die "Failed to install uidmap. Rootless Docker will not work without it."
    fi
fi
echo ""

# === GPG KEYRING ===
if [ ! -f "$KEYRING_FILE" ]; then
    if gum spin --spinner dot --title "Creating keyrings directory..." -- \
        install -m 0755 -d "$KEYRING_DIR"; then
        success "Keyrings directory ready"
    else
        die "Failed to create keyrings directory: $KEYRING_DIR"
    fi

    if gum spin --spinner dot --title "Downloading Docker GPG key..." -- \
        curl -fsSL "$KEYRING_URL" -o "$KEYRING_FILE"; then
        chmod a+r "$KEYRING_FILE"
        success "Docker GPG key installed"
    else
        die "Failed to download Docker GPG key from $KEYRING_URL"
    fi
else
    info "Docker GPG key already present"
fi
echo ""

# === APT REPOSITORY ===
if [ ! -f "$REPO_FILE" ]; then
    info "Detecting Ubuntu codename..."

    ubuntu_codename=""
    if [ -f /etc/os-release ]; then
        ubuntu_codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")
    fi
    if [ -z "$ubuntu_codename" ]; then
        die "Could not determine Ubuntu codename from /etc/os-release"
    fi

    tee "$REPO_FILE" >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${ubuntu_codename}
Components: stable
Signed-By: ${KEYRING_FILE}
EOF
    success "Docker APT repository configured (suite: $ubuntu_codename)"
else
    info "Docker APT repository already configured"
fi
echo ""

# === UPDATE PACKAGE DATABASE ===
if gum spin --spinner dot --title "Updating package database..." -- \
    apt-get update -qq; then
    success "Package database updated"
else
    warn "Package database update encountered issues. Continuing anyway..."
fi
echo ""

# === INSTALL DOCKER PACKAGES ===
if gum spin --spinner dot \
    --title "Installing Docker Engine, CLI, containerd, buildx, compose, rootless-extras..." -- \
    apt-get install -y "${DOCKER_PACKAGES[@]}"; then
    success "Docker packages installed successfully"

    installed_version=""
    installed_version=$(get_package_version "docker-ce")
    if [ -n "$installed_version" ]; then
        info "Installed version: $installed_version"
    fi
else
    die "Failed to install Docker packages"
fi
echo ""

# === DISABLE SYSTEM DAEMON ===
# Start it briefly to confirm the install is healthy, then disable it.
# The rootless script will start a per-user daemon instead.
if gum spin --spinner dot --title "Starting Docker daemon (install validation)..." -- \
    systemctl start docker; then
    success "Docker daemon started - install validated"
else
    die "Failed to start Docker daemon. Check: journalctl -u docker"
fi
echo ""

if gum spin --spinner dot --title "Disabling system-level Docker daemon for rootless setup..." -- \
    systemctl disable --now docker.service docker.socket; then
    success "System-level Docker daemon disabled"
else
    warn "Could not disable system Docker daemon. You may need to do this manually."
fi

if [ -S /var/run/docker.sock ]; then
    rm -f /var/run/docker.sock
    success "Removed /var/run/docker.sock"
fi
echo ""

# === FOOTER ===
gum style --border double --border-foreground 76 --padding "1 2" \
    "System setup complete!" \
    "" \
    "Next: log in as your normal (non-root) user and run:" \
    "  ./install-docker-rootless.sh"
