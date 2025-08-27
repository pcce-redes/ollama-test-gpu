#!/bin/bash
set -euo pipefail

ollama pull deepseek-r1:1.5b
ollama run deepseek-r1:1.5b