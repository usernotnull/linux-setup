#!/usr/bin/env bash
# Module to install all core apt dependencies.

echo "Installing core system packages..."

apt install -y \
  git \
  stow \
  fonts-noto-color-emoji \
  fonts-symbola \
  ttf-bitstream-vera \
  tlp \
  htop \
  workrave \
  ffmpeg \
  imagemagick \
  flatpak \
  gparted \
  ufw \
  curl \
  wget

echo "Core packages installation complete."

#  ibus-typing-booster \
#  nvidia-cuda-toolkit \
#  nvidia-cudnn \
