#!/bin/bash

sudo apt update && sudo apt install -y curl
sudo nvidia-smi -pm 1
nvidia-smi
nvidia-smi topo -m
docker run --rm --gpus all nvidia/cuda:12.6.1-base-ubuntu24.04 nvidia-smi
