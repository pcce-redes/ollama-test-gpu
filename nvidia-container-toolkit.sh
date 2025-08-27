#!/usr/bin/env bash
set -euo pipefail
NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
fi
sudo apt-get update && sudo apt-get install -y jq

KEYRING=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
sudo rm -f "$KEYRING"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o "$KEYRING"

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed "s#deb https://#deb [signed-by=${KEYRING}] https://#g" \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

sudo apt-get update
if [[ -n "${NVIDIA_CONTAINER_TOOLKIT_VERSION:-}" ]]; then
  sudo apt-get install -y \
    nvidia-container-toolkit="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    nvidia-container-toolkit-base="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container-tools="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container1="${NVIDIA_CONTAINER_TOOLKIT_VERSION}"
else
  sudo apt-get install -y nvidia-container-toolkit
fi

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

if [[ -f /etc/docker/daemon.json ]]; then
  sudo jq '. + {"default-runtime":"nvidia"}' /etc/docker/daemon.json \
    | sudo tee /etc/docker/daemon.json >/dev/null
else
  echo '{"default-runtime":"nvidia"}' | sudo tee /etc/docker/daemon.json >/dev/null
fi
sudo systemctl restart docker

docker run --rm --gpus all nvidia/cuda:12.6.1-base-ubuntu24.04 nvidia-smi