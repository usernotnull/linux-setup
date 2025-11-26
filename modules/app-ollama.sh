#!/usr/bin/env bash
# Module to install Ollama via its official shell script.

echo "Installing Ollama for running large language models..."

# Check if Ollama is already installed by looking for the executable
if [ -f /usr/local/bin/ollama ]; then
    echo "✅ Ollama is already installed. Skipping."
    exit 0
fi

# The installation script handles setting up the system service automatically.
curl -fsSL https://ollama.com/install.sh | sh

echo "Ollama installation complete."