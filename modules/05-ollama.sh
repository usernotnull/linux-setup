#!/usr/bin/env bash
# Module to install Ollama via its official shell script.

echo "Installing Ollama for running large language models..."

# The installation script handles setting up the system service automatically.
curl -fsSL https://ollama.com/install.sh | sh

echo "Ollama installation complete."