#!/bin/bash
set -euo pipefail

ollama pull gemma3:4b
ollama run gemma3:4b