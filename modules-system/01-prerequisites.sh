#!/usr/bin/env bash
# Module to install all core apt dependencies.

# Exit immediately if a command exits with a non-zero status
set -e

echo "Installing core system packages..."

apt install -y \
  git \
  stow \
  curl \
  wget \
  libfuse2t64 \
  bind9-host \
  exfatprogs \
  flatpak \
  ufw \
  eza \
  btop \
  workrave \
  ffmpeg \
  zstd \
  pv \
  sqlite3 \
  imagemagick \
  fonts-noto-color-emoji \
  fonts-symbola \
  ttf-bitstream-vera

echo "Core packages installation complete."

  # nvidia-cuda-toolkit \
  # nvidia-cudnn \
  #  ibus-typing-booster \
  #  tlp \
  # gparted \
  # htop \
