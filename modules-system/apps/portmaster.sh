#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Portmaster installer - checks for latest version on GitHub
#              and installs or upgrades as needed.
# USAGE:       sudo ./install-portmaster.sh [--beta]
# REQUIREMENTS: gum, curl, dpkg or rpm
# NOTES:       Must be run as root. Supports amd64 / arm64 on Debian/RPM
#              based distros. Pass --beta to allow pre-release versions.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_VERSION="1.0.0"
CONFIG_DIR="$HOME/.config/portmaster-installer"
LOG_DIR="$HOME/.local/state/portmaster-installer"
LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d_%H-%M-%S").log"
GITHUB_API="https://api.github.com/repos/safing/portmaster/releases"
BASE_DOWNLOAD_URL="https://updates.safing.io/latest"
ALLOW_BETA=false

# === COLORS ===
readonly NC='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m'
readonly BLUE='\033[0;34m' YELLOW='\033[1;33m' CYAN='\033[0;36m'

# === CLEANUP ===
declare -g CLEANUP_FILES=()

cleanup_on_exit() {
    for file in "${CLEANUP_FILES[@]:-}"; do
        [ -n "$file" ] && rm -f "$file"
    done
}
trap cleanup_on_exit EXIT

make_temp_file() {
    local temp=""
    temp=$(mktemp) || die "Failed to create temp file"
    CLEANUP_FILES+=("$temp")
    echo "$temp"
}

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
    log_message "=== Session started ==="
    rotate_logs
    trap 'log_message "=== Session ended (exit: $?) ==="' EXIT
}

rotate_logs() {
    local log_count=""
    log_count=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l) || true
    if [ "${log_count:-0}" -gt 10 ]; then
        find "$LOG_DIR" -name "*.log" -type f -printf '%T+ %p\n' 2>/dev/null |
            sort | head -n -10 | cut -d' ' -f2- |
            xargs -r rm -f || true
    fi
}

# === ARCHITECTURE DETECTION ===
get_arch() {
    local machine=""
    machine=$(uname -m)
    case "$machine" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    armv7l) echo "armhf" ;;
    *) die "Unsupported architecture: $machine" ;;
    esac
}

# === PACKAGE FORMAT DETECTION ===
get_pkg_format() {
    if command -v dpkg >/dev/null 2>&1; then
        echo "deb"
    elif command -v rpm >/dev/null 2>&1; then
        echo "rpm"
    else
        die "No supported package manager found (dpkg or rpm required)"
    fi
}

# === VERSION HELPERS ===

# Returns the currently installed version, or empty string if not installed.
# For deb: only counts as installed if status is exactly "install ok installed".
# dpkg -s returns 0 even for residual config-only packages, so we check Status field.
get_installed_version() {
    local fmt="${1:-}"
    local ver=""
    if [ "$fmt" = "deb" ]; then
        local status=""
        status=$(dpkg-query -W -f='${Status}' portmaster 2>/dev/null) || true
        if [ "$status" = "install ok installed" ]; then
            ver=$(dpkg-query -W -f='${Version}' portmaster 2>/dev/null) || true
        fi
    elif [ "$fmt" = "rpm" ]; then
        if rpm -q portmaster >/dev/null 2>&1; then
            ver=$(rpm -q --queryformat '%{VERSION}' portmaster 2>/dev/null) || true
        fi
    fi
    echo "${ver:-}"
}

# Compare semver: returns 0 if $1 >= $2, 1 otherwise
version_gte() {
    local a="${1:-0.0.0}"
    local b="${2:-0.0.0}"
    # Use sort -V to compare
    local lowest=""
    lowest=$(printf '%s\n%s' "$a" "$b" | sort -V | head -n1)
    [ "$lowest" = "$b" ]
}

# Fetch latest release version from GitHub API
get_latest_version() {
    local releases_json=""
    releases_json=$(make_temp_file)

    if ! gum spin --spinner dot --title "Fetching latest release info from GitHub..." -- \
        bash -c "curl -fsSL '${GITHUB_API}' > '${releases_json}' 2>&1"; then
        die "Failed to fetch release information from GitHub"
    fi

    local latest_ver=""
    if [ "$ALLOW_BETA" = "true" ]; then
        # Pick the very first release (could be pre-release)
        latest_ver=$(grep -m1 '"tag_name":' "$releases_json" |
            sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/') || true
    else
        # Skip pre-releases: find first release where prerelease == false
        # Parse with awk since we avoid jq dependency
        latest_ver=$(awk '
            /"tag_name":/ { tag=$0; gsub(/.*"tag_name": *"v/, "", tag); gsub(/".*/, "", tag) }
            /"prerelease": false/ { print tag; exit }
        ' "$releases_json") || true
    fi

    [ -n "$latest_ver" ] || die "Could not determine latest version from GitHub"
    echo "$latest_ver"
}

# Build download URL
build_download_url() {
    local version="${1:-}"
    local arch="${2:-}"
    local fmt="${3:-}"
    local pkg_name=""

    # Capitalize first letter of package name for .deb style: Portmaster_X.Y.Z_arch.deb
    if [ "$fmt" = "deb" ]; then
        pkg_name="Portmaster_${version}_${arch}.deb"
    else
        pkg_name="Portmaster_${version}_${arch}.rpm"
    fi

    echo "${BASE_DOWNLOAD_URL}/linux_${arch}/packages/${pkg_name}"
}

# === INSTALLATION ===
install_package() {
    local pkg_path="${1:-}"
    local fmt="${2:-}"

    if [ "$fmt" = "deb" ]; then
        if ! gum spin --spinner dot --title "Installing package..." -- \
            bash -c "dpkg -i '${pkg_path}' 2>&1"; then
            # Try to fix broken deps
            gum spin --spinner dot --title "Fixing dependencies..." -- \
                bash -c "apt-get install -f -y 2>&1" || true
            dpkg -i "$pkg_path" >/dev/null 2>&1 || die "Installation failed"
        fi
    elif [ "$fmt" = "rpm" ]; then
        if ! gum spin --spinner dot --title "Installing package..." -- \
            bash -c "rpm -Uvh '${pkg_path}' 2>&1"; then
            die "Installation failed"
        fi
    fi
}

# === PARSE ARGUMENTS ===
for arg in "$@"; do
    case "$arg" in
    --beta) ALLOW_BETA=true ;;
    --help | -h)
        echo "Usage: sudo $0 [--beta]"
        echo "  --beta    Allow pre-release/beta versions"
        exit 0
        ;;
    *) warn "Unknown argument: $arg" ;;
    esac
done

# === MAIN ===

gum style --border double --border-foreground 212 --padding "1 2" --margin "1 0" \
    "Portmaster Installer v${SCRIPT_VERSION}" "" \
    "Privacy firewall by Safing"

setup_logging
check_dependencies gum curl

# Root check
if [ "$EUID" -ne 0 ]; then
    die "This script must be run as root. Try: sudo $0"
fi

echo ""
ARCH=$(get_arch)
PKG_FMT=$(get_pkg_format)
info "System: Linux ${ARCH} | Package format: ${PKG_FMT}"
echo ""

# Get installed version
INSTALLED_VER=$(get_installed_version "$PKG_FMT")
if [ -n "$INSTALLED_VER" ]; then
    info "Installed version: ${INSTALLED_VER}"
else
    info "Portmaster is not currently installed"
fi

# Get latest version
LATEST_VER=$(get_latest_version)
info "Latest $([ "$ALLOW_BETA" = "true" ] && echo "beta" || echo "stable") version: ${LATEST_VER}"
echo ""

# Compare versions
if [ -n "$INSTALLED_VER" ] && version_gte "$INSTALLED_VER" "$LATEST_VER"; then
    success "Portmaster is already up to date (v${INSTALLED_VER})"
    exit 0
fi

# Decide action label
if [ -n "$INSTALLED_VER" ]; then
    ACTION_LABEL="Upgrade from v${INSTALLED_VER} to v${LATEST_VER}"
else
    ACTION_LABEL="Install Portmaster v${LATEST_VER}"
fi

gum style --border rounded --border-foreground 212 --padding "1 2" \
    "Ready to: ${ACTION_LABEL}"
echo ""

gum confirm "Proceed with installation?" --default=true || {
    info "Installation cancelled by user"
    exit 0
}
echo ""

# Build download URL
DOWNLOAD_URL=$(build_download_url "$LATEST_VER" "$ARCH" "$PKG_FMT")
log_message "Download URL: $DOWNLOAD_URL"
info "Downloading from: ${DOWNLOAD_URL}"
echo ""

# Download package
PKG_FILE=$(make_temp_file)
PKG_FILE="${PKG_FILE}.${PKG_FMT}"
CLEANUP_FILES+=("$PKG_FILE")

if ! gum spin --spinner dot --title "Downloading Portmaster v${LATEST_VER}..." -- \
    bash -c "curl -fL '${DOWNLOAD_URL}' -o '${PKG_FILE}' 2>&1"; then
    die "Download failed. Check the URL or your internet connection: ${DOWNLOAD_URL}"
fi

# Verify download size > 0
if [ ! -s "$PKG_FILE" ]; then
    die "Downloaded file is empty. The version ${LATEST_VER} may not have a ${PKG_FMT} package for ${ARCH}."
fi

success "Download complete"
echo ""

# Install
install_package "$PKG_FILE" "$PKG_FMT"

echo ""
success "Portmaster v${LATEST_VER} installed successfully!"
echo ""

gum style --border rounded --border-foreground 76 --padding "1 2" \
    "Portmaster has been installed." \
    "" \
    "Start it from your application menu or run:" \
    "  systemctl status portmaster"
