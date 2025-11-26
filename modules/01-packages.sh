#!/usr/bin/env bash
# Module to install all core apt dependencies.

echo "Installing core system packages..."

apt install -y \
  git \
  fonts-noto-color-emoji \
  fonts-symbola \
  tlp \
  htop \
  workrave \
  ffmpeg \
  imagemagick \
  flatpak \
  gparted \
  stow \
  ufw

echo "Core packages installation complete."

#  ibus-typing-booster \
#  nvidia-cuda-toolkit \
#  nvidia-cudnn \