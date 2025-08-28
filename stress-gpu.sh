#!/bin/bash
set -euo pipefail
DURATION="${1:-60}"
IMAGE="nvidia/cuda:12.6.1-devel-ubuntu24.04"

docker run --rm --gpus all $IMAGE nvidia-smi >/dev/null

# 2) source
if [ ! -d gpu-burn ]; then
  git clone https://github.com/wilicc/gpu-burn.git
fi

docker run --rm --gpus all \
  -v "$PWD/gpu-burn:/ws" -w /ws $IMAGE \
  bash -lc 'apt-get update && apt-get install -y make g++ >/dev/null && make -j"$(nproc)" COMPUTE=89'

docker run --rm --gpus all \
  -v "$PWD/gpu-burn:/ws" -w /ws $IMAGE \
  ./gpu_burn "$DURATION"
