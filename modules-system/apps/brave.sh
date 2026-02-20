#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Installs Brave Browser via its official APT repository.
#              Idempotent - safe to run multiple times.
# USAGE:       sudo ./install-brave.sh
# REQUIREMENTS: gum, curl, apt, dpkg
# NOTES:       Must be run as root or with sudo.
#              Adds the official Brave APT repository if not already configured.
#              Skips installation if Brave is already installed.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_VERSION="1.0.0"
APP_PACKAGE="brave-browser"
REPO_FILE="/etc/apt/sources.list.d/brave-browser-release.sources"
KEYRING_FILE="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
KEYRING_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
REPO_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser.sources"

LOG_DIR="$HOME/.local/state/install-brave"
LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d_%H-%M-%S").log"

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
    mkdir -p "$LOG_DIR" || die "Failed to create log directory"
    rotate_logs
    log_message "=== Session started ==="
    trap 'log_message "=== Session ended (exit: $?) ==="' EXIT
}

rotate_logs() {
    local log_count
    log_count=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l)

    if [ "$log_count" -gt 10 ]; then
        find "$LOG_DIR" -name "*.log" -type f -printf '%T+ %p\n' |
            sort | head -n -10 | cut -d' ' -f2- |
            xargs -r rm -f
    fi
}

# === HEADER ===
gum style --border double --border-foreground 212 --padding "1 2" --margin "1 0" \
    "Brave Browser Installer v${SCRIPT_VERSION}" \
    "" \
    "Installs Brave via the official APT repository"

# === LOGGING ===
setup_logging
check_dependencies gum curl dpkg apt

# === VALIDATIONS ===
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root or with sudo"
fi

# === ALREADY INSTALLED CHECK ===
if dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" >/dev/null 2>&1; then
    success "Brave Browser is already installed"

    installed_version=""
    if installed_version=$(dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}'); then
        if [ -n "$installed_version" ]; then
            info "Installed version: $installed_version"
        fi
    fi

    echo ""
    gum style --border rounded --border-foreground 76 --padding "0 2" \
        "Nothing to do - Brave Browser is up to date."
    exit 0
fi

info "Brave Browser not found. Proceeding with installation..."
echo ""

# === CONFIGURE REPOSITORY ===
if [ ! -f "${REPO_FILE}" ]; then
    gum style --foreground 212 "Configuring Brave Browser APT repository..."
    echo ""

    if gum spin --spinner dot --title "Downloading GPG keyring..." -- \
        curl -fsSL "${KEYRING_URL}" -o "${KEYRING_FILE}"; then
        success "GPG keyring installed"
    else
        die "Failed to download GPG keyring from ${KEYRING_URL}"
    fi

    if gum spin --spinner dot --title "Downloading repository configuration..." -- \
        curl -fsSL "${REPO_URL}" -o "${REPO_FILE}"; then
        success "Repository configuration installed"
    else
        die "Failed to download repository configuration from ${REPO_URL}"
    fi

    echo ""
else
    info "Brave APT repository is already configured"
    echo ""
fi

# === UPDATE PACKAGE DATABASE ===
if gum spin --spinner dot --title "Updating package database..." -- \
    apt-get update -qq; then
    success "Package database updated"
else
    warn "Package database update encountered issues. Continuing anyway..."
fi
echo ""

# === INSTALL BRAVE ===
if gum spin --spinner dot --title "Installing ${APP_PACKAGE}..." -- \
    apt-get install -y "${APP_PACKAGE}"; then
    success "Brave Browser installed successfully"

    installed_version=""
    if installed_version=$(dpkg -l 2>/dev/null | grep "^ii.*${APP_PACKAGE}" | awk '{print $3}' 2>/dev/null); then
        if [ -n "$installed_version" ]; then
            info "Installed version: $installed_version"
        fi
    fi
else
    die "Failed to install ${APP_PACKAGE}"
fi

# === FOOTER ===
echo ""
gum style --border double --border-foreground 76 --padding "1 2" \
    "Brave Browser installation completed successfully!" \
    "" \
    "Launch Brave from your applications menu or run: brave-browser"
