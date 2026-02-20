#!/usr/bin/env bash
#==============================================================================
# DESCRIPTION: Configures Docker rootless mode for the current user.
#              Must be run as a normal (non-root) user - do NOT use sudo.
#              Idempotent - safe to run multiple times.
# USAGE:       ./install-docker-rootless.sh
# REQUIREMENTS: gum, dockerd-rootless-setuptool.sh (from docker-ce-rootless-extras)
# NOTES:       Run install-docker-system.sh as root first.
#              This script configures a per-user Docker daemon so that
#              docker commands work without sudo.
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_VERSION="1.0.0"

LOG_DIR="$HOME/.local/state/install-docker"
LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d_%H-%M-%S")_rootless.log"

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
ROOTLESS_SOCK="${XDG_RUNTIME_DIR}/docker.sock"

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
    log_count=$(find "$LOG_DIR" -name "*_rootless.log" -type f 2>/dev/null | wc -l)

    if [ "$log_count" -gt 10 ]; then
        find "$LOG_DIR" -name "*_rootless.log" -type f -printf '%T+ %p\n' |
            sort | head -n -10 | cut -d' ' -f2- |
            xargs -r rm -f
    fi
}

# === HEADER ===
gum style --border double --border-foreground 212 --padding "1 2" --margin "1 0" \
    "Docker Rootless Setup v${SCRIPT_VERSION}" \
    "" \
    "Step 2 of 2: Configures a rootless Docker daemon for: $(whoami)" \
    "The daemon will run as you, without requiring sudo."

# === LOGGING & DEPENDENCIES ===
setup_logging
check_dependencies gum systemctl

printf "Install Docker rootless? [y/N]: "
read -r confirm
echo

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log "$ICON_WARN" "Restore cancelled by user"
    exit 0
fi

# === PRIVILEGE CHECK ===
# Must be a normal user - root and sudo sessions are both rejected
if [ "$EUID" -eq 0 ]; then
    die "Do not run this script as root or with sudo. Run it as your normal user account."
fi

if [ -n "${SUDO_USER:-}" ]; then
    die "Do not run this script with sudo. Run it directly as your normal user account."
fi

info "Configuring rootless Docker for user: $(whoami) (UID: $(id -u))"
echo ""

# === CHECK SYSTEM DOCKER WAS INSTALLED FIRST ===
if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    die "dockerd-rootless-setuptool.sh not found. Please run install-docker-system.sh as root first."
fi

if ! command -v docker >/dev/null 2>&1; then
    die "docker client not found. Please run install-docker-system.sh as root first."
fi

# === CHECK XDG_RUNTIME_DIR ===
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    die "XDG_RUNTIME_DIR does not exist: $XDG_RUNTIME_DIR. Make sure you are logged in as a full user session (not su)."
fi
info "Runtime directory: $XDG_RUNTIME_DIR"
echo ""

# === CHECK AND INSTALL UIDMAP ===
# newuidmap/newgidmap (provided by uidmap) are required for rootless user namespace mapping
if ! command -v newuidmap >/dev/null 2>&1 || ! command -v newgidmap >/dev/null 2>&1; then
    warn "uidmap is not installed (newuidmap/newgidmap not found)"
    info "Installing uidmap via apt-get..."

    if sudo apt-get install -y uidmap; then
        success "uidmap installed successfully"
    else
        die "Failed to install uidmap. Install it manually with: sudo apt-get install -y uidmap"
    fi
else
    success "uidmap already installed ($(command -v newuidmap))"
fi
echo ""

# === ALREADY CONFIGURED CHECK ===
if systemctl --user is-active --quiet docker.service 2>/dev/null; then
    success "Rootless Docker daemon is already running"

    docker_info_output=""
    if docker_info_output=$(DOCKER_HOST="unix://${ROOTLESS_SOCK}" docker info 2>&1); then
        if echo "$docker_info_output" | grep -i "rootless" >/dev/null 2>&1; then
            success "Confirmed: running in rootless mode"
        else
            warn "Daemon is running but rootless mode could not be confirmed. Check: docker info"
        fi
    fi

    echo ""
    gum style --border rounded --border-foreground 76 --padding "0 2" \
        "Nothing to do - rootless Docker is already active." \
        "" \
        "Run 'docker info' to inspect the current context."
    exit 0
fi

# === ROOTLESS SETUP ===
gum style --foreground 214 \
    "Rootless mode runs the Docker daemon under your user account," \
    "reducing attack surface and removing the need for sudo on docker commands."
echo ""

info "Running dockerd-rootless-setuptool.sh install..."
echo ""

if XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" dockerd-rootless-setuptool.sh install; then
    success "Rootless Docker configured successfully"
else
    die "dockerd-rootless-setuptool.sh failed. Check the output above for details."
fi
echo ""

# === ENABLE LINGERING ===
# Lingering allows the user systemd instance (and therefore the Docker daemon)
# to survive after the user logs out - required for servers and CI environments.
if command -v loginctl >/dev/null 2>&1; then
    if gum spin --spinner dot --title "Enabling systemd user lingering..." -- \
        loginctl enable-linger "$(whoami)"; then
        success "Lingering enabled - daemon will persist after logout"
    else
        warn "Could not enable lingering. The Docker daemon may stop when you log out."
    fi
    echo ""
fi

# === START THE USER DAEMON ===
if gum spin --spinner dot --title "Starting rootless Docker daemon..." -- \
    systemctl --user start docker; then
    success "Rootless Docker daemon started"
else
    die "Failed to start rootless Docker daemon. Check: journalctl --user -u docker"
fi
echo ""

# === ENABLE ON LOGIN ===
if gum spin --spinner dot --title "Enabling rootless Docker daemon on login..." -- \
    systemctl --user enable docker; then
    success "Rootless Docker daemon enabled on login"
else
    warn "Could not enable Docker daemon on login. You may need to start it manually each session."
fi
echo ""

# === VERIFY ===
info "Verifying rootless Docker connection..."

docker_info_output=""
if docker_info_output=$(DOCKER_HOST="unix://${ROOTLESS_SOCK}" docker info 2>&1); then
    if echo "$docker_info_output" | grep -i "rootless" >/dev/null 2>&1; then
        success "Rootless daemon confirmed - docker info shows rootless context"
    else
        warn "Docker is responding but rootless mode could not be confirmed. Check: docker info"
    fi
else
    warn "Could not connect to rootless Docker socket yet. The daemon may still be starting."
    info "Try running 'docker info' after logging out and back in."
fi
echo ""

# === SHELL ENVIRONMENT HINT ===
# Remind user to set DOCKER_HOST if they use a non-standard socket path
current_shell_socket="${DOCKER_HOST:-}"
if [ -z "$current_shell_socket" ]; then
    gum style --foreground 214 --border normal --border-foreground 214 --padding "0 1" \
        "Add this to your shell profile (~/.bashrc or ~/.zshrc) if docker commands" \
        "cannot find the daemon after login:" \
        "" \
        "  export DOCKER_HOST=unix://${ROOTLESS_SOCK}"
    echo ""
fi

# === FOOTER ===
gum style --border double --border-foreground 76 --padding "1 2" \
    "Rootless Docker setup complete for: $(whoami)" \
    "" \
    "Verify your install:" \
    "  docker run hello-world" \
    "" \
    "Manage your daemon:" \
    "  systemctl --user start|stop|status|restart docker" \
    "" \
    "View daemon logs:" \
    "  journalctl --user -u docker -f"
