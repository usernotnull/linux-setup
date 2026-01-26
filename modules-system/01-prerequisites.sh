#!/bin/bash
#==============================================================================
# DESCRIPTION: Install core system packages with optional NVIDIA CUDA support
#
# USAGE:       sudo ./install-core-packages.sh
#
# REQUIREMENTS:
#   - Must run as root or with sudo
#   - Active internet connection
#   - Debian/Ubuntu-based system (apt package manager)
#
# NOTES:
#   - Script will update system packages before installing new ones
#   - CUDA toolkit installation is optional (prompted during execution)
#==============================================================================

set -euo pipefail

# === CONFIGURATION ===
# Core packages to install (one per line for maintainability)
CORE_PACKAGES=(
  git
  stow
  curl
  wget
  libfuse2t64
  bind9-host
  exfatprogs
  flatpak
  ufw
  eza
  btop
  ffmpeg
  zstd
  sqlite3
  imagemagick
  fonts-noto-color-emoji
  fonts-symbola
  ttf-bitstream-vera
  yq
  p7zip-full
)

# Optional NVIDIA packages
NVIDIA_PACKAGES=(
  nvidia-cuda-toolkit
  nvidia-cudnn
)

# === HELPER FUNCTIONS ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$(cd "$SCRIPT_DIR/../" && pwd)/.bash_utils"

if [[ -f "$UTILS_PATH" ]]; then
  source "$UTILS_PATH"
else
  echo "❌ Error: .bash_utils not found at $UTILS_PATH"
  exit 1
fi

ICON_PACKAGE="📦"
ICON_NVIDIA="🎮"

# === HEADER ===
hr
log "$ICON_START" "Core Package Installation"
hr
echo

# === VALIDATIONS ===
# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  die "This script must be run as root or with sudo"
fi

# Verify we're on a Debian/Ubuntu system
if ! command -v apt >/dev/null 2>&1; then
  die "This script requires apt package manager (Debian/Ubuntu)"
fi

# Check internet connectivity
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  warn "No internet connection detected"
  read -r -p "Continue anyway? [y/N]: " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    die "Installation cancelled - internet connection required"
  fi
fi

# === MAIN LOGIC ===

# 1. Update Package Lists & Perform Full Upgrade
info "🔄" "Updating APT package lists..."
if apt update -yqq; then
  success "$ICON_SUCCESS" "Package lists updated."
else
  warn "APT update returned a non-zero exit code. Proceeding, but errors may occur."
fi

info "🚀" "Performing full system upgrade..."
if apt full-upgrade -yqq; then
  success "$ICON_SUCCESS" "System upgrade complete."
else
  error "❌" "Full upgrade failed. Check for held packages or conflicts."
  exit 1
fi
echo

log "$ICON_PACKAGE" "Installing ${#CORE_PACKAGES[@]} core packages..."

# Track successful installations
installed_count=0
failed_packages=()

# Install packages with progress indication
for package in "${CORE_PACKAGES[@]}"; do
  if dpkg -l | grep "^ii  $package " >/dev/null 2>&1; then
    info "$ICON_SUCCESS" "$package (already installed)"
    installed_count=$((installed_count + 1))
  else
    if apt install -y "$package" >/dev/null 2>&1; then
      success "$ICON_PACKAGE" "$package installed"
      installed_count=$((installed_count + 1))
    else
      warn "$package installation failed"
      failed_packages+=("$package")
    fi
  fi
done

echo
log "$ICON_SUCCESS" "Core package installation: $installed_count/${#CORE_PACKAGES[@]} successful"

if [ ${#failed_packages[@]} -gt 0 ]; then
  warn "Failed to install: ${failed_packages[*]}"
fi

# === NVIDIA CUDA INSTALLATION ===
echo
info "$ICON_NVIDIA" "NVIDIA CUDA toolkit and cuDNN installation option available"

# Ensure we're reading from the terminal
if [ -t 0 ]; then
  read -r -p "Install NVIDIA CUDA toolkit and cuDNN? [y/N]: " install_nvidia
else
  warn "Not running in interactive terminal, skipping NVIDIA package installation"
  install_nvidia="n"
fi

if [[ "${install_nvidia:-n}" =~ ^[Yy]$ ]]; then
  log "$ICON_NVIDIA" "Installing NVIDIA packages..."

  nvidia_installed=0
  for package in "${NVIDIA_PACKAGES[@]}"; do
    if apt install -y "$package" >/dev/null 2>&1; then
      success "$ICON_NVIDIA" "$package installed"
      nvidia_installed=$((nvidia_installed + 1))
    else
      warn "$package installation failed"
    fi
  done

  if [ "$nvidia_installed" -eq ${#NVIDIA_PACKAGES[@]} ]; then
    success "$ICON_NVIDIA" "NVIDIA packages installed successfully"
  else
    warn "Some NVIDIA packages failed to install"
  fi
else
  info "$ICON_NVIDIA" "Skipping NVIDIA package installation"
fi

# === FOOTER ===
echo
hr
success "$ICON_SUCCESS" "Package installation complete!"
info "💡" "Consider rebooting if kernel packages were updated"
hr
