#!/usr/bin/env bash
# Module to install all core apt dependencies.

echo "Installing core system packages..."

apt install -y \
  fonts-noto-color-emoji \
  fonts-symbola \
  tlp \
  htop \
  workrave \
  ibus-typing-booster \
  ffmpeg \
  nvidia-cuda-toolkit \
  nvidia-cudnn \
  imagemagick \
  flatpak \
  software-properties-common \
  gparted \
  ufw

echo "Core packages installation complete."