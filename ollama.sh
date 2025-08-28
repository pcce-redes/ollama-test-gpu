#!/bin/bash
set -euo pipefail

ollama pull deepseek-r1:8b
ollama run deepseek-r1:8b