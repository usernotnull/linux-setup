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
  libfuse2 \
  htop \
  gparted \
  exfatprogs \
  flatpak \
  ufw \
  eza \
  nvidia-cuda-toolkit \
  nvidia-cudnn \
  workrave \
  vlc \
  ffmpeg \
  imagemagick \
  fonts-noto-color-emoji \
  fonts-symbola \
  ttf-bitstream-vera

echo "Core packages installation complete."

#  ibus-typing-booster \
#  tlp \
