#!/bin/bash
set -euo pipefail
DURATION="${1:-600}"   # 10 minutos padrão
if [ ! -d gpu-burn ]; then
  git clone https://github.com/wilicc/gpu-burn.git
fi
cd gpu-burn
make -j"$(nproc)" COMPUTE=89
./gpu_burn "$DURATION"
