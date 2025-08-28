#!/bin/bash
set -euo pipefail
sudo apt update && sudo apt install -y curl ubuntu-drivers-common
sudo ubuntu-drivers autoinstall
sudo apt-get install -y nvidia-driver nvidia-cuda-toolkit
sudo reboot
