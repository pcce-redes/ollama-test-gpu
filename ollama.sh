#!/bin/bash
set -euo pipefail
sudo apt update && sudo apt install -y curl
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable --now ollama
ollama --version && ollama list

